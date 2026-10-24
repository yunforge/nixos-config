# Wayland/GNOME 通用环境变量
{
  lib,
  config,
  myLib,
  ...
}:
let
  cfg = config.mySystem.desktop;
  # AWT 的 sun.java2d.uiScale 只接受整数，分数值（如 1.5）会被静默忽略，
  # 导致 4K 分数缩放主机上 Java 应用整体落在 1x、文字偏小。
  # 按桌面声明的 scale 向上取整：scale=1 → 1，>1 → 2。
  # XWayland 光标尺寸：niri/GTK 侧统一按 24 逻辑像素配置（cursor.kdl、
  # gtk.cursorTheme.size），libXcursor 却只认物理图像尺寸。分数缩放主机上
  # niri 会加载 xcursor-size*2 的纹理再缩放，故此处同样按 scale 翻倍，
  # 否则 scale=1 的主机会拿到比原生光标大一倍的 X11 光标。
  xcursorSize = 24 * (if cfg.scale > 1 then 2 else 1);
  javaUiScale = if cfg.scale > 1 then 2 else 1;
in
{
  config = lib.mkIf cfg.enable {
    environment.sessionVariables = {
      XDG_DATA_HOME = "$HOME/.local/share";
      XDG_SESSION_TYPE = "wayland";
      GDK_BACKEND = "wayland";
      QT_QPA_PLATFORM = "wayland";
      # QT_QPA_PLATFORMTHEME_QT6 = "gnome";
      # 注释：恢复 Qt 客户端自绘标题栏
      # 原为 GNOME SSD 而设，Niri 的 SSD 极简会导致标题栏消失
      # QT_WAYLAND_DISABLE_WINDOWDECORATION = "1";
      ELECTRON_OZONE_PLATFORM_HINT = "auto";
      _JAVA_AWT_WM_NONREPARENTING = "1";
      _JAVA_OPTIONS = "-Dawt.useSystemAAFontSettings=true -Dswing.aatext=true -Dsun.java2d.uiScale=${toString javaUiScale}";
      RUST_BACKTRACE = "1";
      # XWayland 应用（Steam 及其游戏）光标主题/大小：
      # Niri 自身从 config.kdl 读取光标配置，但 XWayland 走 XCURSOR_* 环境变量；
      # 缺失时 libXcursor 回退默认光标（Steam 里出现小且方向异常的箭头）。
      XCURSOR_THEME = myLib.theme.cursor;
      XCURSOR_SIZE = toString xcursorSize;
    };
  };
}
