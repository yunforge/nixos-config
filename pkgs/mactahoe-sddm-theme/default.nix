# MacTahoe SDDM 登录主题（vinceliuice，macOS Tahoe 风格）
# 取自上游 MacTahoe-kde 仓库的 sddm/ 目录；nixpkgs 未收录，自行打包。
#
# 该主题是 KDE Breeze 登录主题的改造版：QML 里 import 了 org.kde.plasma.*、
# org.kde.kirigami、org.kde.breeze.components 与 Qt5Compat.GraphicalEffects，
# 因此运行时需要这些 QML 模块在 greeter 的 QML2_IMPORT_PATH 上——由
# modules/nixos/desktop/sddm.nix 把它们加进 services.displayManager.sddm.extraPackages。
#
# 只用 MacTahoe-6.0（Qt6/Plasma6）变体；5.0 变体 import org.kde.plasma.core 2.0，
# 在 Plasma6 时代已不存在，不打包。
#
# Plasma 6.8 从 org.kde.breeze.components 删掉了 VirtualKeyboardLoader，而本主题
# 仍直接实例化它（缺类型时 greeter 会 "Fallback to embedded theme"）。故把
# plasma-workspace v6.0.0 的该组件（Wayland 实现）作为本地 QML 类型随主题一起装，
# 详见 virtualkeyboard/ 里的文件头。
{
  lib,
  stdenvNoCC,
  fetchFromGitHub,
}:

stdenvNoCC.mkDerivation {
  pname = "mactahoe-sddm-theme";
  version = "unstable-2026-11-17";

  src = fetchFromGitHub {
    owner = "vinceliuice";
    repo = "MacTahoe-kde";
    rev = "cbf6a1f71b591d143184855d62f6272ce533e7c3";
    hash = "sha256-atdHgr9pCfg/VE8GGWF+4MZu6nRmVCz9TiylVATAwzs=";
  };

  dontBuild = true;

  installPhase = ''
    runHook preInstall

    themeRoot="$out/share/sddm/themes"
    for variant in Light Dark; do
      dest="$themeRoot/MacTahoe-$variant"
      mkdir -p "$dest"
      cp -r sddm/MacTahoe-6.0/. "$dest/"
      # 上游把深/浅色背景与预览图单独放在 sddm/images/，install.sh 按变体拷进主题目录
      cp "sddm/images/Background-$variant.jpeg" "$dest/Background.jpeg"
      cp "sddm/images/Preview-$variant.jpeg" "$dest/Preview.jpeg"
      # 变体后缀只加在主题标识上（与上游 install.sh 一致，别动 Website 里的 MacTahoe-kde）
      sed -i "/^Name=/s/MacTahoe/MacTahoe-$variant/" "$dest/metadata.desktop"
      sed -i "/^Theme-Id=/s/MacTahoe/MacTahoe-$variant/" "$dest/metadata.desktop"
      # 上游 Main.qml 把电源/重启等按钮图标写死成发行版路径 /usr/share/sddm/themes/MacTahoe，
      # NixOS 下主题在 store 里、该路径不存在，改为指向本主题的真实目录，否则图标全丢。
      sed -i "s|/usr/share/sddm/themes/MacTahoe|$dest|g" "$dest/Main.qml"
      # 本地 QML 类型：补上 Plasma 6.8 已移除的 VirtualKeyboardLoader（见文件头）
      install -m644 ${./virtualkeyboard}/VirtualKeyboardLoader.qml \
        ${./virtualkeyboard}/VirtualKeyboard_wayland.qml "$dest/"
    done

    runHook postInstall
  '';

  meta = {
    description = "MacOS Tahoe like SDDM login theme (from MacTahoe-kde)";
    homepage = "https://github.com/vinceliuice/MacTahoe-kde";
    license = lib.licenses.lgpl3Plus;
    platforms = lib.platforms.linux;
  };
}
