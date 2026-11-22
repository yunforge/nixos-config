# WhiteSur SDDM 登录主题（vinceliuice，macOS Big Sur 风格）
#
# 取自 WhiteSur-kde 的 `sddm/WhiteSur-6.2`（Qt 6 / Plasma 6 变体），
# 只装深色 `WhiteSur-dark` 一套；用户会话已切到 WhiteSur 浅色，登录界面
# 暂时保持深色，避免本轮只改桌面外观时连带影响 greeter。
#
# 与 MacTahoe 登录主题同源（都是 KDE Breeze 登录主题的改造版），运行时需要
# `plasma-workspace` / `libplasma` / `plasma5support` / `kirigami` /
# `qt5compat` / `qtsvg` 的 QML 模块，见 modules/nixos/desktop/sddm.nix 的
# `extraPackages`。
#
# Plasma 6.8 从 `org.kde.breeze.components` 删掉了 VirtualKeyboardLoader，
# 而本主题仍直接实例化它；缺类型时 greeter 会回退到内嵌主题。包内把
# `pkgs/sddm-virtualkeyboard/` 的 Wayland 实现装到主题目录，作为本地 QML 类型。
{
  lib,
  stdenvNoCC,
  whitesur-kde,
}:

stdenvNoCC.mkDerivation {
  pname = "whitesur-sddm-theme";
  inherit (whitesur-kde) version src;

  dontBuild = true;

  installPhase = ''
    runHook preInstall

    dest="$out/share/sddm/themes/WhiteSur-dark"
    install -d "$dest"
    cp -r "$src/sddm/WhiteSur-6.2/." "$dest/"

    # 上游 install.sh 按变体拷背景与预览图，并把主题标识改成 WhiteSur-dark。
    cp "$src/sddm/images/background-dark.jpeg" "$dest/background.jpeg"
    cp "$src/sddm/images/preview-dark.jpeg" "$dest/preview.jpeg"
    sed -i "/^Name=/s/WhiteSur/WhiteSur-dark/" "$dest/metadata.desktop"
    sed -i "/^Theme-Id=/s/WhiteSur/WhiteSur-dark/" "$dest/metadata.desktop"
    sed -i "s/WhiteSur/WhiteSur-dark/g" "$dest/Main.qml"

    # 上游 Main.qml 把电源/重启等图标写死成发行版路径
    # /usr/share/sddm/themes/WhiteSur；NixOS 下主题在 store 里、该路径不存在，
    # 改为指向本主题的真实目录，否则图标全丢。
    sed -i "s|/usr/share/sddm/themes/WhiteSur-dark|$dest|g" "$dest/Main.qml"

    # 本地 QML 类型：补上 Plasma 6.8 已移除的 VirtualKeyboardLoader
    install -m644 ${../sddm-virtualkeyboard}/VirtualKeyboardLoader.qml \
      ${../sddm-virtualkeyboard}/VirtualKeyboard_wayland.qml "$dest/"

    runHook postInstall
  '';

  meta = {
    description = "WhiteSur SDDM login theme (from WhiteSur-kde)";
    homepage = "https://github.com/vinceliuice/WhiteSur-kde";
    license = lib.licenses.gpl3Plus;
    platforms = lib.platforms.linux;
  };
}
