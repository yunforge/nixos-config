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

    # 把「顶层窗口装饰」压成直角（原来是 $wm_radius = 24）。KDE 侧 KWin 现在用
    # 圆角 opaque 窗饰（kde-appearance.nix）；本包若启用，直角 GTK 窗口会与
    # KDE 的圆角不一致，启用前需先核对外观。只改顶层窗口框：
    # GTK3 `decoration` / `.ssd`、GTK4 `window.csd` 及其 headerbar 顶角、
    # GTK4 Chromium/Edge 的 `headerbar.titlebar`。内层 19/18/16/14/12、
    # popup / tooltip / messagedialog，以及 $wm_radius 变量本身都不动。
    #
    # niri 仍通过 geometry-corner-radius 8 裁切窗口，所以这里的 0 不会改变
    # niri 会话里最终看到的窗口外角。
    perl -0pi -e 's/decoration \{\n  transition: none;\n  border-radius: \$wm_radius;/decoration {\n  transition: none;\n  border-radius: 0;/' src/sass/gtk/_common-3.0.scss
    perl -0pi -e 's/\.ssd & \{\n    border-radius: \$wm_radius \$wm_radius 0 0;/.ssd & {\n    border-radius: 0;/' src/sass/gtk/_common-3.0.scss
    perl -0pi -e 's/border-radius: \$wm_radius;/border-radius: 0;/' src/sass/gtk/_common-4.0.scss
    perl -0pi -e 's/border-top-left-radius: \$wm_radius;/border-top-left-radius: 0;/' src/sass/gtk/_common-4.0.scss
    perl -0pi -e 's/border-top-right-radius: \$wm_radius;/border-top-right-radius: 0;/' src/sass/gtk/_common-4.0.scss
    perl -0pi -e 's/border-radius: \$wm_radius \$wm_radius 0 0;/border-radius: 0;/' src/sass/gtk/apps/_gnome-40.0.scss
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
