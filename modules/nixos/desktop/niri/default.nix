# Niri 窗口管理器 — 系统级配置
{
  lib,
  config,
  pkgs,
  inputs,
  ...
}:
let
  cfg = config.mySystem.desktop.niri;
  desktopCfg = config.mySystem.desktop;
in
{
  # 选项就近定义在实现模块（与 distrobox.nix / steam.nix 同构）；
  # 域内默认值（mkDefault true）由聚合模块 ../default.nix 给出。
  options.mySystem.desktop.niri.enable = lib.mkEnableOption "Niri 窗口管理器";

  config = lib.mkIf (cfg.enable && desktopCfg.enable) {
    # 启用 niri
    programs.niri.enable = true;

    # 修补 niri-session 脚本，静默 systemd/dbus 弃用警告
    programs.niri.package = pkgs.niri.overrideAttrs (prev: {
      postPatch = (prev.postPatch or "") + ''
        substituteInPlace resources/niri-session \
          --replace-fail 'systemctl --user import-environment' 'systemctl --user import-environment >/dev/null 2>&1' \
          --replace-fail 'dbus-update-activation-environment --all' 'dbus-update-activation-environment --all >/dev/null 2>&1'
      '';
    });

    # 触控板
    services.libinput.enable = true;

    # Polkit + 密钥环
    security.polkit.enable = true;
    services.gnome.gnome-keyring.enable = true;

    # 认证代理：polkit-gnome 的二进制位于 libexec/，加入 systemPackages 后
    # 也不会出现在 PATH 上，此处包一层同名 wrapper 供按名调用。
    # startup.kdl 是 git 仓库内的纯文本（symlink 进 ~/.config/niri），
    # 无法插入 store 路径，只能依赖 PATH 解析。
    environment.systemPackages = [
      (pkgs.writeShellScriptBin "polkit-gnome-authentication-agent-1" ''exec ${pkgs.polkit_gnome}/libexec/polkit-gnome-authentication-agent-1 "$@"'')
    ];

    # dconf 数据库
    programs.dconf.enable = true;

    # 桌面门户
    xdg.portal = {
      enable = true;
      extraPortals = with pkgs; [
        xdg-desktop-portal-gtk
        xdg-desktop-portal-gnome
      ];
      config.niri = {
        default = lib.mkForce "gtk;gnome";
      };
    };

    # 注意：XDG_CURRENT_DESKTOP 由 niri-session 在会话启动时自动设置，不要在此处
    # 全局写死（本仓库只装 Niri 一个会话，但 XWayland 应用也读这个变量）。
    # 远程桌面：不预放行 3389——仓库不启用任何 RDP 服务端（gnome-remote-desktop
    # 有意不开，WinApps 是出站连接），需要时随服务一并开。
  };
}
