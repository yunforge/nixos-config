# CLI 工具配置
# 门控：目录导入即生效（myHome.cli.enable 控制整个 CLI 层），无中间层开关；
# 单独关闭某个叶子（如 tmux）用该叶子自己的 enable 选项。
{
  lib,
  config,
  pkgs,
  ...
}:
let
  cliCfg = config.myHome.cli;
in
{
  imports = [
    ./yazi.nix
    ./tmux.nix
    ./distrobox.nix
    ./yt-dlp.nix
    ./daily-checkin.nix
  ];

  config = lib.mkIf cliCfg.enable {
    home.packages = with pkgs; [
      fastfetch
      lazydocker
      delta
      claude-code
      pi-coding-agent
      codex
      herdr
      unzip
      gzip
      tree
      file
      net-tools
      duf
      glow
      hugo
      ffmpeg
    ];

    # lazygit：包由模块提供（上面 home.packages 里不再列）。
    # settings 非空 ⇒ HM 接管 ~/.config/lazygit/config.yml（首次激活会把 lazygit 自己写的
    # 那个空文件备成 .hm-bak），所以在 UI 里改的配置不会持久 —— 改配置回这里。
    # delta 只作为 lazygit 的 diff renderer；git 本体（`git diff` / `git log`）没配 pager。
    programs.lazygit = {
      enable = true;

      settings = {
        gui = {
          nerdFontsVersion = "3";
          showCommandLog = false;
          showBottomLine = true;
          scrollOffMargin = 2;
          scrollOffBehavior = "margin";
        };

        git = {
          autoFetch = true;
          autoRefresh = true;

          # 注意写的是新 schema 的 diffRenderers，不是到处抄得到的那份
          # `git.paging = { colorArg; pager; useConfig; }`：后者是旧键，lazygit 启动时会
          # 迁移它（paging → pagers → diffRenderers，pager → command）并**写回**配置文件；
          # 而 HM 生成的 config.yml 是只读的 store 软链，写回必然失败 → lazygit 直接退出 1。
          diffRenderers = [
            {
              command = "delta --dark --paging=never";
              colorArg = "always";
              useConfig = false;
            }
          ];

          commit = {
            signOff = false;
            autoWrapCommitMessage = true;
            autoWrapWidth = 72;
          };
        };

        os = {
          edit = "nvim {{filename}}";
          editAtLine = "nvim +{{line}} {{filename}}";
          editAtLineAndWait = "nvim +{{line}} {{filename}}";
          openDirInEditor = "nvim {{dir}}";
          editInTerminal = true;
        };

        notARepository = "prompt";
        promptToReturnFromSubprocess = true;
        confirmOnQuit = false;
      };
    };

    # btop：终端系统监控。此前只装包、零配置，于是它跑在自带的 Default 主题上
    # （终端里多出第 4 套配色）。这里补主题。
    #
    # theme_background 的更正：当时写“置 True 会让 btop 自画不透明底，使
    # frosted-glass.kdl 的 opacity 与模糊完全无从体现”——这是错的。niri 的
    # opacity 作用在**整个窗口**上（文档：“applied to every surface of the
    # window”），与窗口里面画不画底无关，磨砂效果一直都在。
    # 而且本主题的 theme[main_bg] = #303446 恰好等于 ghostty（Catppuccin Frappe）的背景色，两种取值
    # 在这个配色下是**视觉空操作**。
    # 保留 false 的真实理由：让 btop 的背景始终跟随终端，而不是把 #303446
    # 再硬编码一份——以后改终端主题的背景色时不会两者脱节。
    programs.btop = {
      # 包由本模块提供，故上面 home.packages 里不再列 btop
      enable = true;
      settings = {
        # 主题由 Noctalia 统一管理（gui/desktop/linux/niri/noctalia.nix 启用 builtin "btop" 模板）：
        # Noctalia 把当前调色板渲染成 ~/.config/btop/themes/noctalia.theme，其 apply.sh 会把这个
        # 键改成 "noctalia"。这里先写好最终值，apply.sh 检测到已是目标值即不写 —— 于是对 HM 的
        # 只读软链没有任何写操作（否则实测报「只读文件系统」）。亮/暗由调色板切换带出。
        color_theme = "noctalia";
        # btop 内嵌配置说明：set to False if you want terminal background
        # transparency
        theme_background = false;
      };
      # 不能用 programs.btop.themes：那个选项写出的软链不允许被覆盖（HM 的 checkLinkTargets
      # 会判成外来文件而整份激活失败）。主题文件交给 Noctalia。
    };

    myHome.appearance.switchTargets = [
      {
        live = ".config/fastfetch/config.jsonc";
        dark = ".config/theme-variants/fastfetch/dark.jsonc";
        light = ".config/theme-variants/fastfetch/light.jsonc";
      }
      {
        live = ".config/fastfetch/logo/deepseek_whale.txt";
        dark = ".config/theme-variants/fastfetch/logo-dark.txt";
        light = ".config/theme-variants/fastfetch/logo-light.txt";
      }
    ];

    # fastfetch 亮/暗两套：配置 jsonc 与 logo 文本（逐行内嵌 ANSI）各一份变体，
    # 由 theme-apply 翻软链。亮色那份的 10 阶渐变是**重算**的（Latte 底色上 blue 只有
    # 4.34:1，达不到 AA，改用 subtext1 → mauve 两个端点插值），算据写在那个文件的注释里。
    home.file = {
      ".config/fastfetch/config.jsonc" = {
        source = ../../../../assets/fastfetch/nixos-01.jsonc;
        force = true;
      };
      # fastfetch 的 logo：DeepSeek 像素鲸鱼（32 列 × 22 像素行，半块字符渲染成 11 行），
      # 逐行内嵌真彩色 ANSI（前景 = 上半像素、背景 = 下半像素）。之所以是文件而不是内置
      # logo，见 jsonc 里的说明 —— 内置 logo 不可着色（fastfetch 实测，输出逐字节相同）。
      # 亮色那份换了一套更深的调色板（浅底上 #4E6FFF 的腹部会糊掉）。
      # 图形取自 @lhh010 的手绘像素材（dsh-ui-whale），经 MIT 许可的 dsh-TUI 转成半块像素图：
      # https://github.com/ccch1mneyyy/dsh-TUI （MIT, Copyright (c) 2026 chimney）。
      # 两套变体的文件名与源文件同名，只靠软链区分，所以 jsonc 里那句 source 路径
      # （~/.config/fastfetch/logo/deepseek_whale.txt）不用变。
      ".config/fastfetch/logo/deepseek_whale.txt" = {
        source = ../../../../assets/fastfetch/logo/deepseek_whale.txt;
        force = true;
      };

      ".config/theme-variants/fastfetch/dark.jsonc".source = ../../../../assets/fastfetch/nixos-01.jsonc;
      ".config/theme-variants/fastfetch/light.jsonc".source =
        ../../../../assets/fastfetch/nixos-01-light.jsonc;
      ".config/theme-variants/fastfetch/logo-dark.txt".source =
        ../../../../assets/fastfetch/logo/deepseek_whale.txt;
      ".config/theme-variants/fastfetch/logo-light.txt".source =
        ../../../../assets/fastfetch/logo/deepseek_whale-light.txt;
    };

  };
}
