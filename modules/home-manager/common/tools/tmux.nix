# Tmux — 终端复用器
#
# 除基础配置外，本模块可选启用「会话持久化」：重启后把会话/窗口/面板/布局/每个
# 面板的 cwd（可选：滚动历史、白名单程序）原样带回来。由 tmux-resurrect 负责
# 快照的写入与重建，tmux-continuum 负责"server 刚启动时自动恢复"。
{
  lib,
  config,
  pkgs,
  ...
}:
let
  cfg = config.mengw.cli.tools.tmux;
  persist = cfg.persistence;
  cliCfg = config.mengw.cli;

  resurrect = pkgs.tmuxPlugins.resurrect;
  continuum = pkgs.tmuxPlugins.continuum;

  # nixpkgs 的 tmux 插件包把 rtp 指到「入口 .tmux 文件」（HM 的 run-shell 直接吃它），
  # 存档/恢复脚本在同一个目录下的 scripts/ 里。
  resurrectSave = "${builtins.dirOf resurrect.rtp}/scripts/save.sh";
  resurrectRestore = "${builtins.dirOf resurrect.rtp}/scripts/restore.sh";

  # 白名单里每一项都要**自带双引号**再交给 resurrect：它靠 `eval set $(_restore_list)`
  # 还原列表，裸写 `~nvim->nvim *` 时 `*` 会被 eval 当通配符拆成独立单词、参数占位符
  # 因此失效（实测：程序能起来但参数全丢）。带引号后 eval 才把整项当一个词。
  processList = lib.concatMapStringsSep " " (p: "\"${p}\"") persist.restoreProcesses;

  # 保存入口。定时器、注销/关机、手动（tmux-persist-save）三处共用。
  #
  # 两个必须显式处理的坑（都是实测出来的）：
  #   ① 无 server 时不能保存：resurrect 的 save.sh 不检查 server 是否存在，此时
  #      dump_* 全部无输出 → files_differ 判为「快照变了」→ 把空快照写成 last，
  #      上一份存档直接被毁掉。故先用 list-sessions 探测。
  #   ② 不能直接执行 save.sh：其 shebang 是 /usr/bin/env bash，而 NixOS 没有
  #      /usr/bin；tmux 的 run-shell 靠 shell 的 ENOEXEC 回退能跑起来，systemd
  #      的 Exec* 是直接 execve，没有回退，故统一用 bash 显式调用。
  saveScript = pkgs.writeShellScriptBin "tmux-persist-save" ''
    set -u

    log() {
      printf '[%s] [tmux-persist-save] [DEBUG] %s\n' \
        "$(${pkgs.coreutils}/bin/date -Is)" "$*" >&2
    }

    tmux=${pkgs.tmux}/bin/tmux

    if ! "$tmux" list-sessions >/dev/null 2>&1; then
      log "没有运行中的 tmux server，跳过保存（避免空快照覆盖 last）"
      exit 0
    fi

    # 实际目录取自 server 选项（与 restore 同源），不写死 Nix 里的那份
    log "保存会话快照到 $("$tmux" show-option -gqv @resurrect-dir)"
    exec ${pkgs.bash}/bin/bash ${resurrectSave} quiet
  '';

  # 登录时拉起 server 并**显式**执行一次恢复。
  #
  # 为什么不用 continuum 的自动恢复（@continuum-restore）来做登录恢复：
  # 它靠「本用户 tmux 进程数 > 1 就算还有别的 server」来判断，任何同时存在的
  # tmux 客户端进程都会被它当成第二个 server（实测：机器上挂着两个游离的
  # `tmux new/attach` 客户端时，登录恢复 100% 静默不生效），而登录路径恰恰
  # 会自己调用 tmux 探测状态。所以登录恢复改为直接调 resurrect 的 restore 脚本，
  # 结果确定、不依赖任何启发式。continuum 仍保留开启，用作「手工启动 server」
  # （WSL 等没有图形会话目标的主机）时的尽力恢复。
  #
  # 占位会话：tmux 在「零会话」时会自行退出（exit-empty），而 restore 需要一个
  # 活着的 server，故先建一个名为 main 的会话把 server 稳住；恢复完成后若快照里
  # 并没有 main（说明它只是占位），且已经有别的会话了，就把它收掉。
  startScript = pkgs.writeShellScriptBin "tmux-persist-start" ''
    set -u

    log() {
      printf '[%s] [tmux-persist-start] [DEBUG] %s\n' \
        "$(${pkgs.coreutils}/bin/date -Is)" "$*" >&2
    }

    export PATH=${
      lib.makeBinPath [
        pkgs.coreutils
        pkgs.gawk
        pkgs.gnugrep
      ]
    }:$PATH
    tmux=${pkgs.tmux}/bin/tmux
    placeholder=main

    if "$tmux" list-sessions >/dev/null 2>&1; then
      log "已有 tmux server（会话：$("$tmux" list-sessions -F '#{session_name}' | tr '\n' ' ')），跳过登录恢复"
      exit 0
    fi

    "$tmux" new-session -d -s "$placeholder" -c "$HOME"
    log "已拉起 tmux server（占位会话 $placeholder），开始按快照恢复"
    "$tmux" run-shell "${pkgs.bash}/bin/bash ${resurrectRestore}"

    snapshot="$("$tmux" show-option -gqv @resurrect-dir)/last"
    if [ -f "$snapshot" ] && ! awk -F'\t' -v s="$placeholder" \
        '$1 == "pane" && $2 == s { found = 1 } END { exit !found }' "$snapshot"; then
      others=$("$tmux" list-sessions -F '#{session_name}' | grep -cvx "$placeholder" || true)
      if [ "$others" -gt 0 ]; then
        "$tmux" kill-session -t "$placeholder" && log "已收掉占位会话 $placeholder"
      fi
    fi

    log "登录恢复完成，当前会话：$("$tmux" list-sessions -F '#{session_name}' 2>/dev/null | tr '\n' ' ')"
  '';

  # 注销/关机路径：先存档、再收 server。写成一个脚本而不是两条 ExecStop，
  # 是为了让「先存后杀」的顺序与失败处理都由本脚本掌握。
  stopScript = pkgs.writeShellScriptBin "tmux-persist-stop" ''
    set -u

    log() {
      printf '[%s] [tmux-persist-stop] [DEBUG] %s\n' \
        "$(${pkgs.coreutils}/bin/date -Is)" "$*" >&2
    }

    ${saveScript}/bin/tmux-persist-save || true

    tmux=${pkgs.tmux}/bin/tmux
    if "$tmux" list-sessions >/dev/null 2>&1; then
      log "注销/关机：关闭 tmux server（快照已存，下次登录自动恢复）"
      "$tmux" kill-server || true
    fi
  '';

  # socket 位置随 HM 的 secureSocket 走：Linux 默认开，socket 在 $XDG_RUNTIME_DIR 下。
  # 单元环境不跟上就会去 /tmp/tmux-$UID 找 socket，和终端里的 tmux 不是同一个 server。
  tmuxEnv = lib.optional config.programs.tmux.secureSocket "TMUX_TMPDIR=%t";

  # 三个封装脚本合成一个包放进 PATH：systemd 单引用各自路径，人（和冒烟测试）
  # 则能直接按名字调用，例如手动存一次 `tmux-persist-save`、排查登录恢复用
  # `tmux-persist-start`。
  tmuxPersistBin = pkgs.symlinkJoin {
    name = "tmux-persist";
    paths = [
      saveScript
      startScript
      stopScript
    ];
  };

  # 只有 Linux 才谈得上 systemd 用户单元（macOS 上插件/快照照常可用，只是没有
  # 登录自启与注销保存，恢复靠手动启动 tmux 时 continuum 触发）
  linuxPersist = persist.enable && pkgs.stdenv.hostPlatform.isLinux;
in
{
  options.mengw.cli.tools.tmux = {
    enable = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "启用 tmux 终端复用器";
    };

    persistence = {
      enable = lib.mkOption {
        type = lib.types.bool;
        default = true;
        description = ''
          启用 tmux 会话持久化：快照落盘 + 登录自动恢复 + 定时/注销/关机自动保存。
          会话/窗口/面板/布局/每个面板的 cwd 会被恢复；滚动历史与运行中的程序需另行开启。
        '';
      };

      autoRestore = lib.mkOption {
        type = lib.types.bool;
        default = true;
        description = ''
          tmux server 启动时自动恢复上次快照。注意 continuum 只在「本用户只有一个
          tmux server」时恢复：同时开着第二个 socket 的 server 会让它静默跳过。
        '';
      };

      restoreProcesses = lib.mkOption {
        type = lib.types.listOf lib.types.str;
        default = [
          "~nvim->nvim *"
          "~vim->vim *"
          "~ssh->ssh *"
          "~tio->tio *"
        ];
        example = [ "~htop->htop" ];
        description = ''
          除 shell 之外，重启后还要重新拉起的程序。写法遵循 tmux-resurrect 的
          `匹配->恢复命令` 约定：`~` 表示「进程名里含该串」即匹配，`->` 右边是实际
          执行的命令，`*` 是原命令参数占位符。本仓库在 NixOS + fish 下必须用
          `~程序->程序 *` 这种形式（fish 传给 execve 的 argv[0] 是解析后的绝对
          路径，默认的按词匹配永远匹配不上），详见 docs/tmux.md。
        '';
      };

      capturePaneContents = lib.mkOption {
        type = lib.types.bool;
        default = false;
        description = ''
          是否连每个面板的滚动历史一起存进快照：开启后重启仍能看到旧输出，
          代价是快照体积随 history-limit（本仓库 50000 行）增长。
        '';
      };

      saveInterval = lib.mkOption {
        type = lib.types.ints.positive;
        default = 15;
        description = "定时保存间隔（分钟）";
      };

      loginTarget = lib.mkOption {
        type = lib.types.str;
        default = "graphical-session.target";
        description = ''
          登录自启单元挂到哪个用户 target 下。默认 graphical-session.target：
          它保证合成器（niri）已经 import-environment 完成，自启的 tmux server 才带
          WAYLAND_DISPLAY / DBUS_SESSION_BUS_ADDRESS，恢复出来的 shell 里启动 GUI
          程序不会「没有桌面环境」。没有图形会话的主机（如 WSL）可改为
          default.target，那里不关心图形环境变量。
        '';
      };

      directory = lib.mkOption {
        type = lib.types.str;
        default = "${config.home.homeDirectory}/.local/state/tmux/resurrect";
        description = ''
          快照目录。resurrect 上游默认写 ~/.tmux/resurrect，这里默认收到 XDG state 下。
        '';
      };
    };
  };

  config = lib.mkIf (cfg.enable && cliCfg.enable) {
    # 交给 HM 的 tmux 模块生成 ~/.config/tmux/tmux.conf（用 home.file 直写会与
    # 模块自身的 xdg.configFile 撞车），配置主体放在外部文件里保持可读。
    #
    # 注意插件的拼接位置：HM 把 plugins 排在 extraConfig **之前**。continuum 的
    # 「状态栏定时保存」是往 status-right 前置注入 #(...continuum_save.sh) 实现的，
    # 而 tmux.conf 末尾的 set -g status-right 会把这个钩子整个覆盖掉。所以下面
    # 明确把 continuum 的自动保存关掉（save-interval 0），改由 systemd 定时器
    # + 注销/关机 ExecStop 保存 —— 不依赖 status-right，也不必改状态栏那几行。
    programs.tmux = {
      enable = true;
      extraConfig = builtins.readFile ./tmux/tmux.conf;

      plugins = lib.mkIf persist.enable [
        {
          plugin = resurrect;
          extraConfig = ''
            # 快照目录 + 需要重新拉起的程序（写法说明见模块内注释与 docs/tmux.md）
            set -g @resurrect-dir '${persist.directory}'
            set -g @resurrect-processes '${processList}'
          ''
          + lib.optionalString persist.capturePaneContents ''
            set -g @resurrect-capture-pane-contents 'on'
          '';
        }
        {
          plugin = continuum;
          extraConfig = ''
            set -g @continuum-restore '${if persist.autoRestore then "on" else "off"}'
            # 0 = 关闭 continuum 自带的状态栏自动保存，改由 systemd 定时器负责
            set -g @continuum-save-interval '0'
          '';
        }
      ];
    };

    # 手动入口：`tmux-persist-save` / `-start` / `-stop`（无 server 时会自行跳过）
    home.packages = lib.optional persist.enable tmuxPersistBin;

    # 登录拉起 server（顺带完成恢复），注销/关机前保存并收 server
    #
    # 这里用 lib.mkIf 而不是把 systemd 段用 lib.optionalAttrs 拼到配置集合上：
    # optionalAttrs 会在「构造模块返回值」时立刻求值条件，而条件里的 cfg/persist
    # 又来自本模块自己定义的选项，于是形成自引用死循环（infinite recursion）。
    # mkIf 的条件是惰性 thunk，等选项收齐后才求值。
    systemd.user.services.tmux-persist = lib.mkIf linuxPersist {
      Unit = {
        Description = "tmux 会话持久化（登录拉起并自动恢复，注销/关机前保存快照）";
        # 必须排在图形会话就绪之后：niri-session/niri 启动时会 import-environment，
        # 之后拉起的 tmux server 才带 WAYLAND_DISPLAY / DBUS_SESSION_BUS_ADDRESS，
        # 恢复出来的 shell 里启动 GUI 程序才不会「没有桌面环境」。
        After = [ persist.loginTarget ];
        PartOf = [ persist.loginTarget ];
      };
      Service = {
        Type = "oneshot";
        RemainAfterExit = true;
        Environment = tmuxEnv;
        ExecStart = "${startScript}/bin/tmux-persist-start";
        ExecStop = "${stopScript}/bin/tmux-persist-stop";
        # 不让 systemd 回收 cgroup：server 的生死由 stopScript 里的 kill-server 决定
        KillMode = "none";
      };
      Install.WantedBy = [ persist.loginTarget ];
    };

    # 定时保存（tmux 状态是「当下」的快照，错过就补跑没有意义，故不 Persistent）
    systemd.user.services.tmux-persist-save = lib.mkIf linuxPersist {
      Unit.Description = "定时保存 tmux 会话快照";
      Service = {
        Type = "oneshot";
        Environment = tmuxEnv;
        ExecStart = "${saveScript}/bin/tmux-persist-save";
      };
    };

    systemd.user.timers.tmux-persist-save = lib.mkIf linuxPersist {
      Unit.Description = "每 ${toString persist.saveInterval} 分钟保存一次 tmux 会话快照";
      Timer = {
        OnBootSec = "5min";
        OnUnitActiveSec = "${toString persist.saveInterval}min";
        Unit = "tmux-persist-save.service";
      };
      Install.WantedBy = [ "timers.target" ];
    };
  };
}
