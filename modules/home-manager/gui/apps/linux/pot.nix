# pot-translation 跨平台划词翻译
{
  lib,
  config,
  pkgs,
  ...
}:
let
  cfg = config.mengw.gui.apps.pot;
  guiCfg = config.mengw.gui;

  pot-icon = pkgs.fetchurl {
    url = "https://raw.githubusercontent.com/pot-app/pot-desktop/master/public/icon.svg";
    hash = "sha256-Fgn8kC4GhIOkzUmGre7OCW5fED5N1AU1KrXbbCh714I=";
  };
  potPackage = pkgs.nur.repos.awa2333.pot-translation;
  pot-desktop = pkgs.makeDesktopItem {
    name = "pot";
    desktopName = "Pot";
    exec = "pot";
    icon = "${pot-icon}";
    comment = "划词翻译";
    categories = [ "Utility" ];
    terminal = false;
    mimeTypes = [ ];
  };
  tesseract = pkgs.tesseract.override {
    enableLanguages = [
      "eng"
      "chi_sim"
      "chi_tra"
    ];
  };

  # Pot 调用封装：按需拉起常驻进程，再打它的本地 HTTP API。
  #
  # 为什么需要它：Pot 是 Tauri 应用，全局热键走 X11 grab，Wayland 下拿不到，
  # 所以 niri 侧（wm/config/binds/apps.kdl）改为直接请求它的本地 API。但该 API
  # 只在 Pot 进程存活时可用，而 niri 不执行 ~/.config/autostart（Pot 自己写的
  # 自启项在这套环境里从来没生效过），于是每次按快捷键都得先确认 Pot 在跑：
  # 没在跑就拉起来、等端口就绪、再调用。
  #
  # 端口取自 Pot 配置 ~/.config/com.pot-app.desktop/config.json 的 server_port
  # （默认 60828）；若在 Pot 设置里改了端口，这里的 PORT 要同步改。
  #
  # 文本来源：selection 动作不再让 Pot 自己抓选区，而是由 pot-ctl 读 PRIMARY
  # 选区（为空时退回剪贴板）再 POST 给 /translate。原因见下方 selection 分支。
  potCtl = pkgs.writeShellScriptBin "pot-ctl" ''
    set -u

    readonly HOST="127.0.0.1"
    readonly PORT="60828"
    readonly BASE="http://$HOST:$PORT"

    case "''${1:-}" in
      selection) mode="selection" ;;   # 取当前文本（选区优先）后翻译
      input)     mode="input" ;;       # 打开输入框翻译
      translate) mode="translate" ;;   # 从 stdin 读文本后翻译（供 OCR 管道调用）
      *)
        printf '[DEBUG] pot-ctl: 未知动作 %s，支持 selection | input | translate\n' "''${1:-<空>}" >&2
        exit 2
        ;;
    esac

    # 探活用裸 TCP 而不是某个 HTTP 端点：Pot 的 /config 会弹出设置窗口，
    # 拿它探活会平白多开一个窗口。
    api_up() { (exec 3<>"/dev/tcp/$HOST/$PORT") 2>/dev/null; }

    if ! api_up; then
      # setsid -f 必须带 -f（永远 fork）：不带时 setsid 直接 exec 成 Pot，
      # 于是 Pot 的父进程就是本脚本；快捷键命令（niri 的 spawn-sh）一退出，
      # Pot 会被连带收走。加了 -f 后中间多一个立即退出的 setsid 父进程，
      # Pot 作为孤儿被 init 收养，得以常驻。
      ${pkgs.util-linux}/bin/setsid -f ${potPackage}/bin/pot >/dev/null 2>&1 </dev/null

      # 实测冷启动端口就绪约 0.3s；15s 上限只为兜住磁盘冷读与首跑
      for ((i = 0; i < 150; i++)); do
        api_up && break
        sleep 0.1
      done

      printf '[DEBUG] pot-ctl: Pot 原先未运行，已拉起并等 API 就绪后调用\n' >&2
    fi

    if ! api_up; then
      printf '[DEBUG] pot-ctl: Pot API %s 在 15s 内未就绪，请确认 pot 可执行\n' "$BASE" >&2
      exit 1
    fi

    case "$mode" in
      input)
        exec ${pkgs.curl}/bin/curl -s -o /dev/null "$BASE/input_translate"
        ;;
      translate)
        exec ${pkgs.curl}/bin/curl -s -o /dev/null --data-binary @- "$BASE/translate"
        ;;
    esac

    # selection：自己取文本再打 /translate，不再走 Pot 的 /selection_translate。
    # 后者读的是 PRIMARY 选区而非剪贴板（两条独立通路），所以「先复制、再按
    # Alt+T」会翻到上一次的选区内容。这里改成「当前选区优先、剪贴板兜底」：
    # 有高亮就翻高亮，选区为空时再翻最近复制的内容。
    text="$(${pkgs.coreutils}/bin/timeout 2 ${pkgs.wl-clipboard}/bin/wl-paste --primary 2>/dev/null || true)"
    if [ -z "$text" ]; then
      text="$(${pkgs.coreutils}/bin/timeout 2 ${pkgs.wl-clipboard}/bin/wl-paste 2>/dev/null || true)"
    fi
    if [ -z "$text" ]; then
      printf '[DEBUG] pot-ctl: 选区和剪贴板都是空的，没有可翻译的内容\n' >&2
      exit 0
    fi

    printf '%s' "$text" | ${pkgs.curl}/bin/curl -s -o /dev/null --data-binary @- "$BASE/translate"
  '';
in
{
  options.mengw.gui.apps.pot.enable = lib.mkOption {
    type = lib.types.bool;
    default = true;
    description = "启用 Pot 划词翻译";
  };

  config = lib.mkIf (cfg.enable && guiCfg.enable) {
    home.packages = [
      potPackage
      potCtl
      pot-desktop
      tesseract
      pkgs.grim
      pkgs.slurp
      pkgs.wl-clipboard
    ];

    home.sessionVariables.TESSDATA_PREFIX = "${tesseract}/share/tessdata";
  };
}
