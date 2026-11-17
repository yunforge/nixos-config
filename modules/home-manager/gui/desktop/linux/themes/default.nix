# Qt/GTK 主题配置
{
  lib,
  config,
  pkgs,
  myLib,
  osConfig,
  ...
}:
let
  cfg = config.myHome.gui.themes;
  desktopCfg = config.myHome.desktop;
in
{
  # 亮/暗两套变体与切换入口（真源：Noctalia 的 theme mode）
  imports = [ ./variants.nix ];

  options.myHome.gui.themes.enable = lib.mkOption {
    type = lib.types.bool;
    default = true;
    description = "启用 Qt/GTK 主题配置";
  };

  config = lib.mkIf (cfg.enable && desktopCfg.enable) {
    # 下面写的是**初始值**，即暗色那一套（与改造前一致）：rebuild 后 HM 的 store 软链
    # 就是它，登录时 theme-apply 再按 Noctalia 当前的 theme mode 覆盖（见 variants.nix）。
    # MacTahoe 的 Dark 变体是中性灰（#242424 / #333333）+ 单一强调色 #0088FF。
    gtk = {
      enable = true;
      theme = {
        package = pkgs.mactahoe-gtk-theme;
        name = "MacTahoe-Dark";
      };
      iconTheme = {
        package = pkgs.mactahoe-icon-theme;
        # 图标主题变体后缀是小写 -dark（区别于 GTK 主题的 MacTahoe-Dark）
        name = "MacTahoe-dark";
      };
      cursorTheme = {
        package = pkgs.bibata-cursors;
        name = myLib.theme.cursor;
        # 24：Bibata 的箭头比 macOS 原版更撑满画布。切回 1.5 倍缩放前的取值
        # （2 倍缩放下曾降到 20）。改这一个数不够 —— 光标的尺寸是**多处各写一份**
        # （niri 的 cursor.kdl、GTK 的 variants.nix、XWayland 的 env.nix、SDDM 的 sddm.nix、
        # KDE 会话的 plasma-workspace/env），改就一起改。
        size = 24;
      };
      font = {
        name = myLib.theme.fontSans;
        size = 12;
      };

      # GTK4/libadwaita 不认 gtk-theme-name，只认 color-scheme：
      # gtk3 侧会写 dconf 的 org.gnome.desktop.interface color-scheme=prefer-dark，
      # gtk4 侧会写 settings.ini 的 gtk-interface-color-scheme=2。
      # 不设则 libadwaita 按 "default"（浅色）渲染，且 GNOME 系应用不跟随桌面。
      colorScheme = "dark";

      # 不再设 gtk.gtk4.theme：~/.config/gtk-4.0/gtk.css 由 gui/themes/variants.nix 拥有
      # （模式无关的单一文件，亮/暗在同一份里用 @media 切；两个模块同时写该文件会冲突）。
      # color-scheme 仍从顶层继承（见上），libadwaita 靠它决定明暗。
    };

    # 这 4 个软链归 theme-apply 运行时接管（按 Noctalia 的 mode 指到亮/暗变体），
    # 加了 force 才能让 HM 跳过碰撞检查 —— 否则下一次 rebuild 时那几个软链指向
    # 变体（不在本 generation 里），HM 会判「would be clobbered」直接中断激活。
    # 不能用 xdg.configFile.… 重写（会和 gtk/qt 模块的同名目标冲突），
    # 故各设一个独立的 force 标记项（force 项只贡献本路径，不重复铺设）。
    xdg.configFile = lib.mkMerge [
      {
        "gtk-3.0/settings.ini".force = true;
        "gtk-4.0/settings.ini".force = true;
        "gtk-4.0/gtk.css".force = true;
        "Kvantum/kvantum.kvconfig".force = true;
      }

      # KDE Plasma 会话里 XWayland 应用的 XCURSOR_SIZE 修正（否则微信窗口内光标是
      # 桌面的两倍大）。仓库全局 `XCURSOR_SIZE=48`（env.nix）是给 niri/xwayland-satellite
      # 的 X11 物理翻倍用的；KDE 下 KWin 自己在 Xwayland 上把 X 资源 `Xcursor.size` 设成
      # 24（与桌面光标一致），但 libXcursor 会优先读环境变量，于是经 systemd --user 启动的
      # XWayland 应用（微信）仍继承 48 → 以 24 的逻辑尺寸加载成 48 物理像素，视觉上大一圈。
      # startplasma 会执行 `~/.config/plasma-workspace/env/*.sh` 并把结果 `import-systemd`
      # 进用户 systemd 环境（`startplasma.cpp` 的 runEnvironmentScripts → importSystemdEnvironment），
      # 故在此把 Plasma 会话的该变量钉回 24；niri 会话不读这个目录，仍用全局 48。
      # 与 plasma.nix 里 KWin 单元的 24 drop-in 一致（那只管 KWin 自己，管不到 XWayland 应用）。
      # 需重建 + 重新登录（登录时 startplasma 才导入）。详见 docs/quirks.md。
      (lib.mkIf osConfig.mySystem.desktop.plasma.enable {
        "plasma-workspace/env/50-xcursor-size.sh".text = ''
          export XCURSOR_SIZE=24
        '';
      })
    ];

    # XWayland 应用（Steam 等）的光标查找路径是 ~/.local/share/icons，
    # gtk.cursorTheme 只写 gsettings、不落地主题文件到该路径，
    # 导致 libXcursor（xwayland-satellite）加载不到 Bibata、回退默认光标。
    # 这里将主题目录软链到搜索路径上（recursive=false 即目录软链）。
    xdg.dataFile."icons/${myLib.theme.cursor}" = {
      source = "${pkgs.bibata-cursors}/share/icons/${myLib.theme.cursor}";
      recursive = false;
    };

    # `default` 主题别名：微信（XWayland 上的 Qt 5）窗口内光标退回原始箭头的原因。
    # xwayland-satellite 的 XSETTINGS 只写 3 个整型键、没有 `Gtk/CursorThemeName`，
    # Qt5 的 QXcbCursor 于是把**空字符串**交给 XcursorSetTheme()，这条 X 连接的主题名
    # 被清空，libXcursor 回落到字面量 `default`；XCURSOR_PATH 里没有目录提供 default/
    # → 全部 ENOENT → Qt 用 X 核心字体光标（10×16 单色）。XCURSOR_THEME 对它无效
    # （那条路径只认 XSETTINGS / Xcursor.theme / default 三档）。
    # 整目录软链成 default 即可闭合这条链；根因与实测见 docs/quirks.md。
    xdg.dataFile."icons/default" = {
      source = "${pkgs.bibata-cursors}/share/icons/${myLib.theme.cursor}";
      recursive = false;
    };

    qt = {
      enable = true;
      # 保持不变：Wayland 下 Qt 的窗口装饰由平台主题提供，与控件样式是两回事。
      # 换掉它会让自绘标题栏消失（本仓库 env.nix 里就是为此才恢复 Qt 自绘）。
      platformTheme.name = "adwaita";
      # 停用 Kvantum：不设 qt.style.name，HM 就不会导出全局 QT_STYLE_OVERRIDE=kvantum。
      # 该变量经 systemd 用户环境被所有会话继承，而 Kvantum 的 SVG 样式会把 Kirigami/QML
      # 应用（如 Spectacle）渲成白字压白底、文字不可读（QtWidgets 的 Dolphin 则正常）。
      # 现在所有会话（含 Plasma）都走 platformTheme=adwaita 的原生主题。
      style.name = null;
      kvantum = {
        enable = true;
        # 主题包不用 qt.kvantum.themes 安装：那个选项会把 ~/.config/Kvantum
        # 整个做成指向 store 的软链，而 kvantum.kvconfig 又要写在同一目录下，
        # 两者会打架。改为进 home.packages（落到 XDG_DATA_DIRS，Kvantum 同样会
        # 在那里搜主题，上游自己的 install.sh 就是装到 share/Kvantum）。
        settings.General.theme = "MacTahoeDark";
      };
    };

    # MacTahoe Kvantum 主题文件（保留：theme-apply 仍会切它的浅/深 kvconfig，
    # 但已不再设 QT_STYLE_OVERRIDE，Qt 应用不再使用 Kvantum 样式，属惰性保留）。
    home.packages = [ pkgs.mactahoe-kvantum ];

  };
}
