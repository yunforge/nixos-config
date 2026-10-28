# 角色配置（系统层）：Linux 工作站 — NixOS PC / 笔记本
#
# 组合关系（与 modules/home-manager/profiles/workstation.nix 对应）：
#   系统基础（core：引导 / Nix / 用户 / SSH / locale）
#   + 硬件能力（蓝牙 / 音频 / 网络 / MCU；NVIDIA 由主机按硬件显式开启）
#   + 桌面能力（GDM / Niri / 输入法 / 虚拟化 / 代理）
#
# 主机（hosts/desktop、hosts/laptop）只声明真实差异：硬件、显示器、
# 驱动与主机专属修复。服务器 / WSL 不导入本文件，因此不会被动继承
# 工作站的桌面 / 音视频 / 虚拟化配置。
#
# 原先由各主机文件写的 mySystem.hardware.enable / desktop.enable，
# 在这里是角色的默认开关（mkDefault），主机仍可用 mkForce 覆盖。
{ lib, ... }:
{
  mySystem.hardware.enable = lib.mkDefault true;
  mySystem.desktop.enable = lib.mkDefault true;

  # 虚拟化与代理曾在 hosts/<host>/default.nix 里按桌面能力逐台打开，后由
  # desktop 聚合模块代管，现收口回角色层：libvirtd 是 WinApps / distrobox 的
  # 依赖、代理为 mihomo 客户机转发的前置条件——这是「工作站」的组合，而非
  # 桌面能力本身的要求（server 即便开桌面也不该隐式带出它们）。
  mySystem.virtualization.enable = lib.mkDefault true;
  mySystem.proxy.enable = lib.mkDefault true;
  mySystem.proxy.exposeToVms = lib.mkDefault true;
  # 客户机零配置：virbr0 上的 TCP/DNS 透明转给 mihomo（见 networking/proxy-vm.nix）
  mySystem.proxy.transparentForVms = lib.mkDefault true;

  # 工作站加入 tailnet（desktop / laptop 互相访问；服务器与 WSL 不导入
  # 本角色，不会被启用）。首次使用需手动 sudo tailscale login 一次。
  mySystem.tailscale.enable = lib.mkDefault true;
}
