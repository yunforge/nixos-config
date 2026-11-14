# 系统工具 / 实用程序
{
  lib,
  config,
  pkgs,
  myLib,
  ...
}:
let
  cfg = config.myHome.gui.apps.utilities;
  guiCfg = config.myHome.gui;

  eudic-fixed = myLib.wrapQtXWayland {
    inherit pkgs;
    pkg = pkgs.eudic;
    # 窗口 WM_CLASS 为 eudic，而桌面文件 ID 是 eusoft-eudic，需补充
    # StartupWMClass 让 GNOME Shell / Dash to Panel 正确显示应用图标
    startupWMClass = "eudic";
    extraWrapArgs = ''
      --unset QT_STYLE_OVERRIDE \
      --set XKB_CONFIG_ROOT "${pkgs.xkeyboard_config}/share/X11/xkb" \
      --set GST_PLUGIN_SYSTEM_PATH_1_0 ""
    '';
  };

  # Pulse 的「App 内存占用 / App CPU 占用」只按 /proc/<pid>/exe 的 basename 去
  # 匹配桌面条目的 Exec 程序名，不看窗口 app_id / StartupWMClass，也没有按进程名
  # 直接找图标的回退（实测：把 niri.png 放进主题，Pulse 从不打开它）。Nix 包装
  # 脚本恰好会改掉可执行文件名，于是这些应用在卡片上全是齿轮图标：
  #
  #   niri     exe=niri                 无应用条目（只有 wayland-sessions），也没有图标
  #   Noctalia exe=.noctalia-wrapped    无应用条目
  #   FlClash  exe=FlClashCore（内核子进程）无应用条目
  #   magpie   exe=magpie-bun（插件宿主）  无应用条目
  #   Zen / CLion / Typora / 腾讯会议    exe 与条目 Exec 的 basename 不同
  #
  # 修法：给每个这样的应用补一条 NoDisplay 别名条目，Exec 写成运行时的 exe
  # basename、Icon 指向它自己的图标。别名条目不会出现在启动器里、也不会被执行，
  # 只是给 Pulse 查表用（实测 niri / FlClashCore / magpie-bun
  # / noctalia 四项均从齿轮变成真图标）。见 docs/quirks.md 的 Pulse 条目。
  #
  # 注意：exe basename 由 nixpkgs 的包装方式决定，升级后若包装改名，这里会静默
  # 失配（退回齿轮），照 `readlink -f /proc/<pid>/exe` 的结果改即可。
  niri-icon = pkgs.fetchurl {
    url = "https://raw.githubusercontent.com/YaLTeR/niri/v26.04/docs/wiki/logo/niri-icon.svg";
    # niri 仓库只在文档目录里放 logo，nixpkgs 的 niri 包不带图标
    hash = "sha256-0RUtBQ1QkUPpfUUva0iJVQIXR0QzQZ39Zd5L7hPLp5A=";
  };
in
{
  options.myHome.gui.apps.utilities.enable = lib.mkOption {
    type = lib.types.bool;
    default = true;
    description = "启用系统工具和实用程序";
  };

  config = lib.mkIf (cfg.enable && guiCfg.enable) {
    home.packages = with pkgs; [
      ddcutil
      file-roller
      papers
      gnome-text-editor
      pulse # 系统活动监视器（进程 / CPU / 内存 / GPU / 磁盘 / 网络 / 能耗）
      foliate # eBook阅读器
      gapless # 本地音乐播放器
      # 终端（2026-11-14 起，替代已移除的 Ghostty）：只装包不写配置 —— laptop 无
      # Plasma 会话，不能依赖 plasma6 模块带出 konsole；desktop 的 Plasma 侧也有
      # 一份，同包不冲突
      kdePackages.konsole
      misterdownloadmanager # 下载管理器（Rust，自维护包，见 pkgs/misterdownloadmanager）
      qview # 图片查看
      disktree # 磁盘使用情况树状图
      logisim-evolution
      localsend
      eudic-fixed
      magpie # 各 AI agent 的模型选择器（托盘/窗口版；终端版见 hosts/wsl）
    ];

    # `note <文件>`：用 GNOME 文本编辑器打开；无参数时直接开一个空文档。
    # 只在本模块（Linux 桌面工作站）里定义，server / wsl / macbook 不会继承。
    home.shellAliases.note = "${pkgs.gnome-text-editor}/bin/gnome-text-editor";

    # Pulse 的图标别名条目（为什么需要见上方 let 块注释）：
    # 键 = 运行时 exe 的 basename，值 = 该应用自己的图标名（绝对路径亦可）。
    # 全是 NoDisplay，不进启动器、不被点开，只供 Pulse 查表。
    xdg.desktopEntries =
      lib.mapAttrs'
        (
          exe: icon:
          lib.nameValuePair "pulse-alias-${lib.replaceStrings [ "." ] [ "dot-" ] exe}" {
            name = exe;
            exec = exe;
            inherit icon;
            noDisplay = true;
          }
        )
        {
          niri = "${niri-icon}";
          ".noctalia-wrapped" = "noctalia";
          FlClashCore = "flclash"; # FlClash 内核，没有自己的条目
          magpie-bun = "magpie"; # magpie 的 bun 插件宿主
          ".clion-wrapped" = "clion";
          zen = "zen-browser"; # 条目 Exec=zen-beta，运行时是 zen
          Typora = "typora"; # 条目 Exec=typora，运行时大小写不同
          wemeetapp = "wemeet"; # 条目 Exec=wemeet
        };

    # magpie 的桌面文件。上游 internal/gui/scheme_linux.go 的 registerScheme()
    # 首次运行时会往 ~/.local/share/applications/magpie.desktop 写一份，把当时
    # 那个**绝对 store 路径**钉进 Exec=，用来抢占 magpie:// 协议；而它只在
    # 「文件已指向我自己」时跳过后写，于是升级后没人再更新它，启动器与
    # magpie:// 链接就一直拉起上一个版本（CLI 走 PATH，故不受影响）。
    #
    # 这里由 HM 托管同一路径、按当前版本重写 Exec=，每次 rebuild 都指向新版本；
    # 写的是 ${pkgs.magpie} 的绝对路径，正好等于 magpie 自检用的 os.Executable()，
    # 它的自写会命中「已指向我自己」而直接返回，不报错。
    #
    # 不能改用 xdg.desktopEntries：它写进 profile 的 share/applications
    # （XDG_DATA_DIRS），而 GLib 解析桌面文件时 XDG_DATA_HOME(即 ~/.local/share)
    # 优先，会被这份旧文件盖掉、修不好（已用 GLib 实测确认）。HM 首次接管时，
    # 原文件会被备份成 magpie.desktop.hm-bak（后缀非 .desktop，不被当条目解析）。
    xdg.dataFile."applications/magpie.desktop".text = ''
      [Desktop Entry]
      Type=Application
      Name=magpie
      Comment=Every agent's model. One place.
      Exec=${pkgs.magpie}/bin/magpie %u
      Icon=magpie
      Categories=Development;Utility;
      MimeType=x-scheme-handler/magpie;
      Terminal=false
    '';

    # magpie 开机自启（托盘常驻：网关要在登录时就位，各 agent 才连得上）。
    # 不用 magpie 自带的 `magpie autostart on`：它把 os.Executable() 的**绝对
    # store 路径**写进 ~/.config/autostart/magpie.desktop，升级被 GC 后开机就
    # 起不来（与上面桌面文件同一个坑）。照 FlClash 的既有做法（media.nix）
    # 由 HM 声明一条自制 autostart 条目，Exec 用稳定的命令名走 PATH，恒指向
    # 当前版本；systemd 的 xdg-autostart-generator 会在登录时拉起它。
    # 参数 `tray` 是上游自启的形态（只进托盘、不开窗，见 cli help）。
    xdg.autostart = {
      enable = true;
      entries = [
        (pkgs.writeTextFile {
          name = "magpie.desktop";
          text = ''
            [Desktop Entry]
            Type=Application
            Name=magpie
            Comment=Every agent's model. One place.
            Exec=magpie tray
            Icon=magpie
            Terminal=false
            X-GNOME-Autostart-enabled=true
          '';
        })
      ];
    };

  };
}
