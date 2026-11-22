# Wayland/GNOME 通用环境变量
{
  lib,
  config,
  ...
}:
let
  cfg = config.mySystem.desktop;
  # AWT 的 sun.java2d.uiScale 只接受整数，分数值（如 1.5）会被静默忽略，
  # 导致 4K 分数缩放主机上 Java 应用整体落在 1x、文字偏小。
  # 按桌面声明的 scale 向上取整：scale=1 → 1，>1 → 2。
  javaUiScale = if cfg.scale > 1 then 2 else 1;
in
{
  config = lib.mkIf cfg.enable {
    environment.sessionVariables = {
      XDG_DATA_HOME = "$HOME/.local/share";
      XDG_SESSION_TYPE = "wayland";
      GDK_BACKEND = "wayland";
      QT_QPA_PLATFORM = "wayland";
      # 两个 Qt 变量曾在 GNOME 时代启用、迁到 Niri 后注释（QT_WAYLAND_DISABLE_WINDOWDECORATION=1
      # 会让 Qt 自绘标题栏消失，勿在 Niri 下恢复），历史见 docs/themes.md 与本文件 git log。
      ELECTRON_OZONE_PLATFORM_HINT = "auto";
      _JAVA_AWT_WM_NONREPARENTING = "1";
      _JAVA_OPTIONS = "-Dawt.useSystemAAFontSettings=true -Dswing.aatext=true -Dsun.java2d.uiScale=${toString javaUiScale}";
      RUST_BACKTRACE = "1";
      # XCURSOR_THEME / XCURSOR_SIZE 故意不在这里全局注入：KWin 在 XCURSOR_THEME
      # 非空时会优先拿环境变量当光标主题/逻辑尺寸，等于从 NixOS 侧改写 Plasma 的
      # 光标设置。niri 会话专用的值由 niri 的 environment 段给出
      # （modules/home-manager/gui/desktop/linux/niri/default.nix）。
    };
  };
}
