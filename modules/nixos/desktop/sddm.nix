# SDDM 登录管理器（Wayland greeter，MacTahoe 换肤）
#
# 取代原 GDM：只用 SDDM 做登录器（本体 + Niri / Plasma 会话均在会话菜单里切换），
# 并且不引入 X server —— SDDM 以 Wayland 模式跑 greeter（Plasma 主机用 kwin，其余用 weston kiosk）。
#
# 登录界面用自打包的 mactahoe-sddm-theme（Light / Dark 两套，这里取 Dark，
# 与用户会话的深色外观一致）。
{
  lib,
  config,
  pkgs,
  myLib,
  ...
}:
let
  cfg = config.mySystem.desktop;

  # 登录界面与桌面会话共用一套外观：光标（字体走 greeter 主题体系，图标由
  # 主题自带的 MacTahoe 图标覆盖，只有光标需要显式给全局名 + 尺寸）。
  sddmTheme = "MacTahoe-Dark";
in
{
  config = lib.mkIf cfg.enable {
    # SDDM + Wayland greeter。assertion 要求 xserver.enable 或 wayland.enable 之一为真，
    # 这里显式打开 wayland，不启用 X server。greeter 合成器不在此指定：启用 Plasma 的
    # 主机由 plasma6 模块（mkDefault）设为 kwin，纯 niri 主机回落默认的 weston kiosk，
    # 两者都是 Wayland，不引入 X。
    services.displayManager.sddm = {
      enable = true;
      wayland.enable = true;

      # 主题在 /run/current-system/sw/share/sddm/themes/MacTahoe-Dark
      theme = sddmTheme;

      # greeter 的鼠标指针不读 [Theme] CursorSize（SDDM 只对 breeze 主题补这个键），
      # 而是 Qt Wayland 按 XCURSOR_SIZE / XCURSOR_THEME 选。用户会话已不再全局注入
      # XCURSOR_*（见 modules/nixos/desktop/env.nix），所以这里给 greeter 的值不会被
      # pam_env 的 `DEFAULT=` 覆盖。kwin greeter 仍需 layer-shell 集成。
      settings.General.GreeterEnvironment =
        "XCURSOR_SIZE=24 XCURSOR_THEME=${myLib.theme.cursor}"
        + lib.optionalString (
          config.services.displayManager.sddm.wayland.compositor == "kwin"
        ) " QT_WAYLAND_SHELL_INTEGRATION=layer-shell";

      # MacTahoe 主题的 QML 依赖（仿 KDE Breeze 登录主题）：
      #   org.kde.plasma.components / extras            → libplasma
      #   org.kde.plasma.private.keyboardindicator
      #   org.kde.breeze.components                     → plasma-workspace
      #   org.kde.plasma.plasma5support                 → plasma5support
      #   org.kde.kirigami                              → kirigami
      #   Qt5Compat.GraphicalEffects                    → qt5compat
      #   assets/*.svgz 电源/重启图标                    → qtsvg
      # 这些包的 lib/qt-6/qml 会被 sddm wrapper 拼进 greeter 的
      # NIXPKGS_QT6_QML_IMPORT_PATH（extraPackages 正是为此设计），否则 greeter
      # 会因为缺 QML 模块黑屏/白屏。
      extraPackages = with pkgs.kdePackages; [
        libplasma
        plasma-workspace
        plasma5support
        kirigami
        qt5compat
        qtsvg
      ];

      # 登录界面光标与桌面一致；主题未自带光标，用系统全局名 + 24 号。
      settings.Theme = {
        CursorTheme = myLib.theme.cursor;
        CursorSize = 24;
      };
    };

    # 主题要进系统 profile 才会落在 ThemeDir=/run/current-system/sw/share/sddm/themes
    # 下（SDDM 按名字在那里找 MacTahoe-Dark）。光标主题 Bibata 已在
    # modules/nixos/desktop/default.nix 的 systemPackages 里，无需重复声明。
    environment.systemPackages = [ pkgs.mactahoe-sddm-theme ];
  };
}
