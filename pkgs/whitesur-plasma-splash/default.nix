# WhiteSur 的 Plasma 启动画面
#
# Plasma 6.8 的 ksplashqml 按 `ksplashrc [KSplash] Theme=<id>` 加载
# `Plasma/LookAndFeel` 包里的 `contents/splash/Splash.qml`。这里只装
# WhiteSur 浅色变体的 splash 与 metadata，不装 `contents/layouts` / `defaults`：
# 避免在系统设置的 Global Theme 里应用 WhiteSur 时把面板布局与仓库声明的
# 外观键重置。
#
# 注销界面不在这个包里：logout-greeter 读的是 Plasma/Shell 包，由
# modules/home-manager/gui/desktop/linux/kde-appearance.nix 在用户级构造
# 完整 shell 包副本（理由见那里的注释）。
{
  lib,
  stdenvNoCC,
  whitesur-kde,
}:

stdenvNoCC.mkDerivation {
  pname = "whitesur-plasma-splash";
  inherit (whitesur-kde) version src;

  dontBuild = true;

  installPhase = ''
    runHook preInstall

    lf="$src/plasma/look-and-feel/com.github.vinceliuice.WhiteSur"
    dest="$out/share/plasma/look-and-feel/com.github.vinceliuice.WhiteSur"
    install -d "$dest/contents"
    cp "$lf/metadata.json" "$lf/metadata.desktop" "$dest/"
    cp -r "$lf/contents/splash" "$dest/contents/splash"

    runHook postInstall
  '';

  meta = {
    description = "WhiteSur Plasma splash screen";
    homepage = "https://github.com/vinceliuice/WhiteSur-kde";
    license = lib.licenses.gpl3Plus;
    platforms = lib.platforms.linux;
  };
}
