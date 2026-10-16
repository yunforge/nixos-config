# Fish 配置
{
  lib,
  config,
  ...
}:
let
  cfg = config.mengw.cli.shell.fish;
  cliCfg = config.mengw.cli;
in
{
  options.mengw.cli.shell.fish.enable = lib.mkOption {
    type = lib.types.bool;
    default = true;
    description = "启用 Fish Shell 配置";
  };

  config = lib.mkIf (cfg.enable && cliCfg.enable) {
    # 用官方 fish 集成（source (fzf --fish)）：Ctrl-T 选文件、Ctrl-R 历史、Alt-C 切目录。
    # 注意它会盖掉 fish 预设的 Ctrl-T 交换字符、Alt-C capitalize-word；
    # 不再装 fzf-fish 插件（那套 Ctrl-Alt-F/L/S/P、Ctrl-V 已随之去掉）。
    # FZF_* 走 sessionVariables（babelfish 转成 set -gx），对所有 shell 与子进程生效。
    programs.fzf = {
      enable = true;
      # 启用 Fish 集成
      enableFishIntegration = true;
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
      interactiveShellInit = ''
        set fish_greeting ""
        # 设置终端为英文环境
        set -gx LC_ALL en_US.UTF-8
        set -gx EDITOR nvim
        # 初始化 fnm（HM 无 programs.fnm 模块，需手动 source）
        fnm env --use-on-cd | source
        # API 密钥存放于 git 外的本地文件，避免明文入库
        set -l atria_env ~/.config/atria/env.fish
        if test -f $atria_env
          source $atria_env
        end
      '';
      shellAliases = {
        ".." = "cd ..";
        "..." = "cd ../..";
        arch = "distrobox enter arch";
        ubuntu = "distrobox enter ubuntu";
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
        cc = "claude --dangerously-skip-permissions";
      };
      shellInit = ''
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
