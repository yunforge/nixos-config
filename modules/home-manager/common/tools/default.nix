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
    ./ssh.nix
    ./tmux.nix
    ./distrobox.nix
    ./yt-dlp.nix
    ./daily-checkin.nix
  ];

  config = lib.mkIf cliCfg.enable {
    home.packages =
      with pkgs;
      [
        fastfetch
        lazydocker
        delta
        unzip
        gzip
        tree
        file
        net-tools
        duf
        glow
        hugo
        ffmpeg
        ncdu # du 的交互式替代
      ]
      # 基础诊断工具里的 Linux 专属项；macbook 上不存在对应实现，直接跳过。
      # htop 有 programs.<name> 模块（见下），vmstat（procps）/ ss（iproute2）/
      # systemd-analyze（systemd）由系统基础环境自带，iostat/sar 来自 sysstat。
      ++ lib.optionals pkgs.stdenv.hostPlatform.isLinux [
        iotop # 按进程查看磁盘 I/O（需 root）
        powertop # 功耗/唤醒源分析（需 root）
        # perf 必须与运行内核同源：core 把 boot.kernelPackages 钉在 linuxPackages_latest，
        # 这里跟随同一份；裸 pkgs.perf 对应默认内核，版本会与内核不匹配。
        linuxPackages_latest.perf # Linux 性能分析（perf_events）
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

    # btop：终端系统监控。主题用 btop 自带的 Default：
    # Noctalia 已不再统一渲染各应用主题（2026-11-17），不再生成
    # ~/.config/btop/themes/noctalia.theme。要换主题就改 color_theme 为
    # share/btop/themes/ 下的名字（如 onedark、tokyo-night）。
    #
    # theme_background 保持 false：让 btop 的背景始终跟随终端，而不是把某个
    # 主题的 main_bg 再硬编码一份——以后改终端主题的背景色时不会两者脱节。
    programs.btop = {
      # 包由本模块提供，故上面 home.packages 里不再列 btop
      enable = true;
      settings = {
        color_theme = "Default";
        # btop 内嵌配置说明：set to False if you want terminal background
        # transparency
        theme_background = false;
      };
    };

    # htop：经典进程查看器。不写 settings：HM 只在 settings 非空时才接管
    # ~/.config/htop/htoprc，留空则沿用 htop 自己的交互式配置。
    programs.htop.enable = true;

    myHome.appearance.switchTargets = [
      {
        live = ".config/fastfetch/config.jsonc";
        dark = ".config/theme-variants/fastfetch/dark.jsonc";
        light = ".config/theme-variants/fastfetch/light.jsonc";
      }
    ];

    # fastfetch 亮/暗两套：只有配置 jsonc 一份变体（亮色那份的 10 阶渐变是**重算**的，
    # 色相/彩度与暗色相同，算据写在那个文件的注释里），由 theme-apply 翻软链。
    # logo 不在这条轴上：用 fastfetch 内置的 Arch 字符图（ANSI cyan），两份 jsonc
    # 相同，不再部署图片。
    home.file = {
      # 初始值走亮色那份（与 noctalia.nix 的 theme.mode 一致）；登录时 theme-apply 再按当前模式翻软链。
      ".config/fastfetch/config.jsonc" = {
        source = ../../../../assets/fastfetch/nixos-01-light.jsonc;
        force = true;
      };

      ".config/theme-variants/fastfetch/dark.jsonc".source = ../../../../assets/fastfetch/nixos-01.jsonc;
      ".config/theme-variants/fastfetch/light.jsonc".source =
        ../../../../assets/fastfetch/nixos-01-light.jsonc;
    };

  };
}
