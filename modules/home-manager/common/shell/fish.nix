# Fish 配置
{
  lib,
  config,
  pkgs,
  ...
}:
let
  cfg = config.myHome.cli.shell.fish;
  cliCfg = config.myHome.cli;
in
{
  options.myHome.cli.shell.fish.enable = lib.mkOption {
    type = lib.types.bool;
    default = true;
    description = "启用 Fish Shell 配置";
  };

  config = lib.mkIf (cfg.enable && cliCfg.enable) {
    # 用官方 fish 集成（source (fzf --fish)）：Ctrl-T 选文件、Ctrl-R 历史、Alt-C 切目录。
    # 注意它会盖掉 fish 预设的 Ctrl-T 交换字符、Alt-C capitalize-word；
    # 不再装 fzf-fish 插件（那套 Ctrl-Alt-F/L/S/P、Ctrl-V 已随之去掉）。
    # tmux 内自动改走 fzf-tmux（下方 40% 分屏），非 tmux 仍用 --height 40%。
    # FZF_* 走 sessionVariables（babelfish 转成 set -gx），对所有 shell 与子进程生效。
    programs.fzf = {
      enable = true;
      # 启用 Fish 集成
      enableFishIntegration = true;
      # tmux 集成：在 tmux 内让 Ctrl-T/Ctrl-R/Alt-C 走 fzf-tmux（FZF_TMUX=1）
      tmux.enableShellIntegration = true;
      # 默认 UI
      defaultOptions = [
        "--height 40%"
        "--layout=reverse"
        "--border"
        "--info=inline"
        "--prompt='> '"
        "--pointer='▶'"
        "--marker='✓'"
      ];
      # Ctrl-T：搜索文件
      fileWidget = {
        command = "fd --type f --hidden --follow --exclude .git";

        options = [
          "--preview 'bat --color=always --style=numbers --line-range=:200 {} 2>/dev/null'"
          "--preview-window=right:50%:wrap"
        ];
      };

      # Alt-C：搜索目录
      changeDirWidget = {
        command = "fd --type d --hidden --follow --exclude .git";

        options = [
          "--no-preview"
        ];
      };

      # Ctrl-R：Shell history
      historyWidget = {
        options = [
          "--no-preview"
          "--sort"
          "--exact"
          "--tac"
        ];
      };
      # 默认数据源
      defaultCommand = "fd --type f --hidden --follow --exclude .git";
    };
    programs.fish = {
      enable = true;
      # decors/fish-colored-man 未入 nixpkgs，该插件整体即这一个函数，直接托管
      # 上游: https://github.com/decors/fish-colored-man/blob/master/functions/man.fish
      functions.man = {
        wraps = "man";
        description = "Format and display manual pages";
        body = ''
          set -q man_blink; and set -l blink (set_color $man_blink); or set -l blink (set_color -o red)
          set -q man_bold; and set -l bold (set_color $man_bold); or set -l bold (set_color -o 5fafd7)
          set -q man_standout; and set -l standout (set_color $man_standout); or set -l standout (set_color 949494)
          set -q man_underline; and set -l underline (set_color $man_underline); or set -l underline (set_color -u afafd7)

          set -l end (printf "\e[0m")

          set -lx LESS_TERMCAP_mb $blink
          set -lx LESS_TERMCAP_md $bold
          set -lx LESS_TERMCAP_me $end
          set -lx LESS_TERMCAP_so $standout
          set -lx LESS_TERMCAP_se $end
          set -lx LESS_TERMCAP_us $underline
          set -lx LESS_TERMCAP_ue $end
          set -lx LESS '-R -s'

          set -lx GROFF_NO_SGR yes # fedora

          set -lx MANPATH (string join : $MANPATH)
          if test -z "$MANPATH"
            type -q manpath
            and set MANPATH (command manpath)
          end

          # Check data dir for Fish 2.x compatibility
          set -l fish_data_dir
          if set -q __fish_data_dir
            set fish_data_dir $__fish_data_dir
          else
            set fish_data_dir $__fish_datadir
          end

          set -l fish_manpath (dirname $fish_data_dir)/fish/man
          if test -d "$fish_manpath" -a -n "$MANPATH"
            set MANPATH "$fish_manpath":$MANPATH
            command man $argv
            return
          end
          command man $argv
        '';
      };
      # 无参数时以当前目录打开 Neovim（LazyVim 直接进文件树），有参数时原样透传。
      functions.n = {
        wraps = "nvim";
        description = "Open Neovim in the current directory when no argument is given";
        body = ''
          if test (count $argv) -eq 0
            command nvim .
          else
            command nvim $argv
          end
        '';
      };
      # 全文模糊搜索：rg 列出「文件:行:内容」→ fzf 选择 → 回车用 nvim 跳到命中行。
      # 与 fd（Ctrl-T，只按文件名找）互补。带参数时原样交给 rg（`rgf TODO`、
      # `rgf -t py foo` 都行；pattern 以 - 开头写 `rgf -- -foo`），不带参数先提示
      # 输入 pattern，空回车即退出。
      # --delimiter : 只为让 {1}（文件）/ {2}（行号）能取到字段；fzf 会给占位符
      # 自动加 shell 引号，路径带空格也安全。预览用 bat 高亮命中行，fzf 的
      # +{2}/2 把预览滚到该行附近。rg 隐藏文件、忽略规则、smart-case 全局已配
      # （见 common/shell/default.nix 的 programs.ripgrep）。
      functions.rgf = {
        description = "Full-text fuzzy search (rg + fzf), open the match in Neovim";
        body = ''
          set -l args $argv
          if test (count $args) -eq 0
            read -P 'rg> ' args
            if test -z "$args"
              return
            end
          end
          rg --line-number --no-heading --color=always $args \
            | fzf --ansi --delimiter : \
                --prompt='rg> ' \
                --height 40% \
                --layout=reverse \
                --border \
                --preview 'bat --color=always --style=numbers --highlight-line {2} {1}' \
                --preview-window 'right:60%:+{2}/2' \
                --bind 'enter:become(nvim +{2} {1})'
        '';
      };
      interactiveShellInit = ''
        set fish_greeting ""
        # Ctrl-G：全文模糊搜索（rgf），回车用 nvim 跳到命中行
        bind \cg rgf
        # 设置终端为英文环境
        set -gx LC_ALL en_US.UTF-8
        set -gx EDITOR nvim
        # 初始化 fnm（HM 无 programs.fnm 模块，需手动 source）
        # --shell fish：不依赖进程树推断。某些启动器下进程树里没有可识别的 shell，
        #   不指定时 fnm 会报 "Can't infer shell!"；显式指定后任何启动方式都正常。
        # type -q 兜底：容器/极简环境里没有 fnm 时不至于在启动时报错
        if type -q fnm
            fnm env --use-on-cd --shell fish | source
        end
        # Agent 侧 shell 集成（`cc` 别名、atria 密钥 source）在 common/ai/tools.nix，
        # 随 myHome.ai.enable 门控，不在此处。
      '';
      shellAliases = {
        ".." = "cd ..";
        "..." = "cd ../..";
        arch = "$HOME/.local/bin/arch";
        ubuntu = "$HOME/.local/bin/ubuntu";
        updatewsl = "sudo nixos-rebuild switch --flake ~/Projects/nixos-config#wsl";
        # 构建 desktop 主机 NixOS
        updatedp = "sudo nixos-rebuild switch --flake ~/Projects/nixos-config#desktop";
        # 构建 desktop 主机 NixOS，并获取详细错误信息
        updatedplog = "sudo nixos-rebuild switch --flake ~/Projects/nixos-config#desktop --show-trace --print-build-logs --verbose";
        # 构建 laptop 笔记本 NixOS
        updatelp = "sudo nixos-rebuild switch --flake ~/Projects/nixos-config#laptop";
        # 构建 laptop 笔记本 NixOS，并获取详细错误信息
        updatelplog = "sudo nixos-rebuild switch --flake ~/Projects/nixos-config#laptop --show-trace --print-build-logs --verbose";
        gs = "git status";
        ga = "git add";
        gc = "git commit";
        gp = "git push";
        gl = "git log --oneline --graph --decorate";
        df = "duf --only local";
        duf = "duf --sort usage";
        dufall = "duf --all";
        dufjson = "duf --json";
        zquery = "zoxide query -l -s";
      };
      shellInit = ''
        # 某些“干净环境 + login shell”的启动器只给最小 PATH
        # （/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin），而 fish 不读 /etc/profile，
        # 于是 podman / sudo / nix 等系统命令会缺失。补回 NixOS 系统 profile。
        ${lib.optionalString pkgs.stdenv.hostPlatform.isLinux ''
          fish_add_path /run/wrappers/bin /run/current-system/sw/bin /nix/var/nix/profiles/default/bin
        ''}
        # Home Manager（useUserPackages）把 fzf/fnm/eza/zoxide/bat/fd 等装进
        # per-user profile（${config.home.profileDirectory}/bin）。该目录通常只在
        # 图形会话的 PATH 里；TTY/SSH 等 login shell 继承的 PATH 不含它，而 fish
        # 又不像 bash 那样读 /etc/profile，于是 fzf/fnm 在登录式 shell 里找不到、
        # 启动即报错。这里显式补进 PATH，任何 fish 启动方式都能解析到这些 HM 包。
        fish_add_path ${config.home.profileDirectory}/bin
        fish_add_path ${config.home.homeDirectory}/.cargo/bin
        fish_add_path ${config.home.homeDirectory}/.local/bin
        set -gx NPM_CONFIG_PREFIX ${config.home.homeDirectory}/.npm-global
        fish_add_path ${config.home.homeDirectory}/.npm-global/bin

        function fish_command_picker
          set -l commands_file ~/.config/fish/commands
          if not test -f $commands_file
            echo "commands file not found: $commands_file"
            return 1
          end
          set -l selected (grep -vE '^\s*(#|$)' $commands_file | env FZF_DEFAULT_OPTS="" fzf --prompt="Cmd > " --height=40% --layout=reverse --border --no-hscroll)
          if test -n "$selected"
            set -l cmd (string trim -- (string split -m1 '|' -- $selected)[1])
            commandline --replace -- $cmd
            commandline -f repaint
          end
        end
        bind \co fish_command_picker

        function cheat
          set -l dir ~/.config/cheatsheets
          if not test -d $dir
            echo "cheatsheets directory not found: $dir"
            return 1
          end
          set -l provider $argv[1]
          if test -z "$provider"
            # 一次 jq 调用处理所有文件（input_filename 获取文件名作 fzf key）
            set provider (jq -r '
              input_filename as $f |
              "\($f | sub(".*/";"") | sub("\\.json$";"")):\(.provider): \(.title)"
            ' $dir/*.json | env FZF_DEFAULT_OPTS="" fzf \
              --prompt="Cheatsheet > " \
              --height=40% \
              --layout=reverse \
              --border \
              --with-nth=2.. \
              --preview "jq -r '.binds | to_entries[] | .key as \$cat | .value[] | \"  \" + .key + \"\t\" + .desc + (if .subcat then \" [\" + .subcat + \"]\" else \"\" end)' $dir/{1}.json" \
              --preview-window=right:60% \
              --delimiter=':')
            if test -z "$provider"
              return
            end
            set provider (string split -m1 ':' -- $provider | head -1 | string trim)
          end
          set -l file $dir/$provider.json
          if not test -f $file
            echo "cheatsheet not found: $provider"
            return 1
          end
          # 表格以 | 定界，单元格内的 | 先转成 HTML 实体，否则会撑断行
          set -l md (jq -r '
            "# \(.title)", "",
            (.binds | to_entries[] |
              "## \(.key)", "",
              "| 按键 | 说明 |", "|---|---|",
              (.value[] |
                "| " + (.key | gsub("[|]"; "&#124;")) + " | " +
                (.desc | gsub("[|]"; "&#124;")) +
                (if .subcat then "（" + .subcat + "）" else "" end) + " |"),
              "")
          ' $file)
          # glow 从 stdin 读取终端颜色查询的回复，用管道喂入可在 jq 结束后给出即时 EOF，
          # 避开其在无应答的哑 pty 中挂起；timeout 兜底，异常时退回原始 markdown
          printf '%s\n' $md | timeout 3 glow --style=dark -
          or printf '%s\n' $md
        end
      '';
    };

    xdg.configFile."fish/commands".source = ./fish-commands;
  };
}
