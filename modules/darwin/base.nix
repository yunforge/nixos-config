# macOS 基础配置（所有 Darwin 主机共享）
{ pkgs, ... }:

{
  imports = [
    # Nix 设置 / 镜像源 / overlay 注入的平台无关部分（与 NixOS core 共享单一真源）
    ../shared/nix.nix
  ];

  # 系统级包
  environment.systemPackages = with pkgs; [
    git
    wget
  ];

  # 键盘
  system.keyboard.enableKeyMapping = true;
  system.keyboard.remapCapsLockToControl = false;

  # 安全
  security.pam.services.sudo_local.touchIdAuth = true;

  system.stateVersion = 5;
}
