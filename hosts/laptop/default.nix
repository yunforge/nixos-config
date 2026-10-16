# NixOS 笔记本（Niri 桌面）— workstation 角色
#
# 与 desktop 同为 workstation：系统能力与用户环境由角色模块给出默认值；
# 本文件只声明笔记本的真实差异：内屏、电源管理与 libvirt 修复。
# 曾写的「GNOME 桌面」注释已过时：本机同为 Niri 会话。
{
  config,
  pkgs,
  lib,
  ...
}:
{
  imports = [
    ./hardware.nix
    ./laptop.nix
    ./nvidia.nix
  ];

  networking.hostName = "laptop";

  # 修复 libvirtd TPM2 凭证解密失败
  systemd.services.libvirtd.serviceConfig.LoadCredential = [
    "secrets-encryption-key:/var/lib/libvirt/secrets/secrets-encryption-key"
  ];
  system.activationScripts.libvirtSecretsKey = {
    text = ''
      # umask 077 保证重定向创建密钥时即为 0600，无 0644→0600 的瞬时可读窗口
      umask 077
      if [ ! -f /var/lib/libvirt/secrets/secrets-encryption-key ]; then
        mkdir -p /var/lib/libvirt/secrets
        ${pkgs.openssl}/bin/openssl rand -base64 32 > /var/lib/libvirt/secrets/secrets-encryption-key
        chmod 600 /var/lib/libvirt/secrets/secrets-encryption-key
      fi
    '';
    deps = [ ];
  };

  mySystem = {
    # 内屏 1080p，分数缩放 1.25（desktop.scale 由此派生）
    desktop.monitors = [
      {
        name = "eDP-1";
        mode = "1920x1080@59.977";
        scale = 1.25;
      }
    ];
    # NVIDIA 由主机显式开启（MX150 走 legacy 驱动，PRIME offload）
    hardware.nvidia.enable = true;
  };
}
