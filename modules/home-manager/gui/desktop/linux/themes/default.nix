# Qt/GTK 主题配置
{
  lib,
  config,
  pkgs,
  ...
}:
let
  cfg = config.mengw.gui.themes;
  desktopCfg = config.mengw.desktop;
in
{
  # 亮/暗两套变体与切换入口（真源：Noctalia 的 theme mode）
  imports = [ ./variants.nix ];

  options.mengw.gui.themes.enable = lib.mkOption {
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
        name = "Bibata-Modern-Classic";
        # 24：Bibata 的箭头比 macOS 原版更撑满画布。切回 1.5 倍缩放前的取值
        # （2 倍缩放下曾降到 20）。改这一个数不够 —— 光标的尺寸是**多处各写一份**
        # （niri 的 cursor.kdl、GTK 的 variants.nix、XWayland 的 env.nix、GDM 的 gdm.nix），
        # 改就一起改。
        size = 24;
      };
      font = {
        name = "HarmonyOS Sans SC";
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
    xdg.configFile = {
      "gtk-3.0/settings.ini".force = true;
      "gtk-4.0/settings.ini".force = true;
      "gtk-4.0/gtk.css".force = true;
      "Kvantum/kvantum.kvconfig".force = true;
    };

    # XWayland 应用（Steam 等）的光标查找路径是 ~/.local/share/icons，
    # gtk.cursorTheme 只写 gsettings、不落地主题文件到该路径，
    # 导致 libXcursor（xwayland-satellite）加载不到 Bibata、回退默认光标。
    # 这里将主题目录软链到搜索路径上（recursive=false 即目录软链）。
    xdg.dataFile."icons/Bibata-Modern-Classic" = {
      source = "${pkgs.bibata-cursors}/share/icons/Bibata-Modern-Classic";
      recursive = false;
    };

    qt = {
      enable = true;
      # 保持不变：Wayland 下 Qt 的窗口装饰由平台主题提供，与控件样式是两回事。
      # 换掉它会让自绘标题栏消失（本仓库 env.nix 里就是为此才恢复 Qt 自绘）。
      platformTheme.name = "adwaita";
      style = {
        # 由 adwaita-dark 改为 kvantum：Adwaita 是另一套设计语言（Fedora 的
        # GNOME 移植），控件形状与 GTK 侧的 macOS 观感无关。kvantum 是
        # SVG 驱动的 Qt 样式引擎，配同一个作者的 MacTahoe 主题才能与 GTK 对齐。
        # HM 依 style.name 自动挑选 qtstyleplugin-kvantum（Qt5 + Qt6 各一份）。
        name = "kvantum";
      };
      kvantum = {
        enable = true;
        # 主题包不用 qt.kvantum.themes 安装：那个选项会把 ~/.config/Kvantum
        # 整个做成指向 store 的软链，而 kvantum.kvconfig 又要写在同一目录下，
        # 两者会打架。改为进 home.packages（落到 XDG_DATA_DIRS，Kvantum 同样会
        # 在那里搜主题，上游自己的 install.sh 就是装到 share/Kvantum）。
        settings.General.theme = "MacTahoeDark";
      };
    };

    # Kvantum 主题包（MacTahoeDark：只含深色那一对，见 pkgs/mactahoe-kvantum）
    home.packages = [ pkgs.mactahoe-kvantum ];

  };
}
