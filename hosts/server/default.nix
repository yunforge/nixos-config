# NixOS 服务器（无桌面）— server 角色
#
# 用户环境：公共 CLI/TUI + 语言工具链（HM 侧 server profile）；
# 系统层：最小基础（core）+ 服务器安全策略（SSH 密钥认证、无桌面），
# 不继承工作站的桌面 / 音视频 / 虚拟化配置。
#
# ⚠️ 这是新主机：hardware-configuration.nix 需要在目标机器上跑
# `nixos-generate-config --root /mnt` 后替换（本文件先给一个占位文件系统布局，
# 真实部署前必须改成扫描结果，见 docs/architecture.md 的主机差异表）。
{
  config,
  pkgs,
  lib,
  ...
}:
{
  imports = [
    # ./hardware-configuration.nix  ← 在目标机器上生成后取消注释
  ];

  networking.hostName = "server";

  # 引导：服务器通常用 systemd-boot（UEFI）；若为 BIOS 机器改用 grub。
  # 与 core 的默认值一致，写明是为了让部署者一眼看到这是要确认的项。
  boot.loader.systemd-boot.enable = true;

  # 根文件系统占位：真实分区布局由 hardware-configuration.nix 给出。
  # 保留这个最小声明让 flake 可求值（dry-build / CI 检查需要），
  # 首次部署到真实硬件前替换成扫描结果。
  fileSystems."/" = {
    device = "/dev/disk/by-label/nixos";
    fsType = "ext4";
  };

  # 服务器专属：需要远程管理的服务在这里声明。
  # mySystem 选项体系下没有服务器服务聚合（如 nginx / monitoring），
  # 直接用 NixOS 原生选项按需开启，例如：
  #   services.nginx.enable = true;
  #   services.openssh.ports = [ 22 ];
}
