# MacTahoe GTK 主题（vinceliuice，macOS Tahoe 风格）
# nixpkgs 未收录，此处仿照 whitesur-gtk-theme 打包
# 构建方式：install.sh 内部用 sassc 编译 SCSS 到 $out/share/themes
{
  lib,
  stdenv,
  fetchFromGitHub,
  dialog,
  glib,
  gnome-themes-extra,
  jdupes,
  libxml2,
  perl,
  sassc,
  util-linux,
}:

stdenv.mkDerivation {
  pname = "mactahoe-gtk-theme";
  version = "2026-09-10";

  src = fetchFromGitHub {
    owner = "vinceliuice";
    repo = "MacTahoe-gtk-theme";
    rev = "0aa2a2ba1e07277a49dae9a3b90881c899d2afbe";
    hash = "sha256-P4zevOTHd7KKLj3a9wkaY96tMFMg7iZEpz3NkbdyTwM=";
  };

  nativeBuildInputs = [
    dialog
    glib
    jdupes
    libxml2
    perl
    sassc
    util-linux
  ];

  buildInputs = [
    gnome-themes-extra # adwaita engine for Gtk2
  ];

  postPatch = ''
    find -name "*.sh" -print0 | while IFS= read -r -d ''' file; do
      patchShebangs "$file"
    done

    # 构建环境无 sudo，install 脚本只用于装到 $out，无需提权。
    # 2026-09-10 起上游把 $(which sudo) 换成 SUDO_BIN="$(command -v sudo)"，
    # 未安装 sudo 时该变量为空，脚本里 ''${SUDO_BIN} ... 会退化成直接执行
    # （也正是我们要的）；显式置 false 只是让失败更响亮。
    substituteInPlace libs/lib-core.sh --replace-fail 'SUDO_BIN="$(command -v sudo)"' 'SUDO_BIN=false'

    # 提供假 home 目录，避免读取真实用户信息
    substituteInPlace libs/lib-core.sh --replace-fail 'MY_HOME=$(getent passwd "''${MY_USERNAME}" | cut -d: -f6)' 'MY_HOME=/tmp'

    # 把「顶层窗口装饰」的圆角从 24px（$wm_radius 在 desktop 下的取值）改成 8px，
    # 与 niri 的 geometry-corner-radius 8 以及其它窗口统一。只改三处顶层窗口框：
    # GTK3 `decoration`、GTK4 `window.csd`、GTK4 Chromium/Edge 的 `headerbar.titlebar`
    # （Edge 走 GTK4 时这层框会用到）。内层 19/18/16/14/12、popup / tooltip /
    # messagedialog / .ssd，以及 $wm_radius 变量本身（170 处引用）都不动，避免
    # 波及 cinnamon/gnome-shell/libadwaita 等其它组件。
    perl -0pi -e 's/decoration \{\n  transition: none;\n  border-radius: \$wm_radius;/decoration {\n  transition: none;\n  border-radius: 8px;/' src/sass/gtk/_common-3.0.scss
    perl -0pi -e 's/border-radius: \$wm_radius;/border-radius: 8px;/' src/sass/gtk/_common-4.0.scss
    perl -0pi -e 's/border-radius: \$wm_radius \$wm_radius 0 0;/border-radius: 8px 8px 0 0;/' src/sass/gtk/apps/_gnome-40.0.scss
  '';

  dontBuild = true;

  installPhase = ''
    runHook preInstall

    # 2026-09-10 起上游新增 install_app：把配套的 gnome-theme-switcher
    # 装到 $HOME/.local/{bin,share/applications}。构建沙箱的 HOME 是
    # /homeless-shelter（不可写），cp 失败即 exit 1；而本机主题切换由
    # theme-apply（themes/variants.nix）负责，不需要这个应用。
    # 给一个临时 HOME 让它把文件丢在那里，不污染 $out。
    export HOME=$(mktemp -d)

    mkdir -p $out/share/themes

    # 只装 normal 透明度下的深浅两个变体（默认会生成 4 个组合，冗余）
    ./install.sh \
      --color light \
      --color dark \
      --opacity normal \
      --dest $out/share/themes

    # GDM 登录界面主题：把 other/gdm/theme 编译为 gnome-shell-theme.gresource。
    # gnome-shell 的 gresource 路径在编译期烘焙进二进制，只能由 NixOS overlay
    # 覆盖 gnome-shell 包内同名文件实现 GDM 换肤（见 desktop/gnome 模块）
    mkdir -p $out/share/gnome-shell
    glib-compile-resources \
      --sourcedir=other/gdm/theme \
      --target=$out/share/gnome-shell/gnome-shell-theme.gresource \
      other/gdm/gnome-shell-theme.gresource.xml

    jdupes --quiet --link-soft --recurse $out/share

    runHook postInstall
  '';

  meta = {
    description = "MacOS Tahoe like theme for GTK desktops";
    homepage = "https://github.com/vinceliuice/MacTahoe-gtk-theme";
    license = lib.licenses.mit;
    platforms = lib.platforms.unix;
  };
}
