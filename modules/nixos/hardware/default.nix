# 硬件模块聚合
# mySystem.hardware.enable = true 时自动启用所有子模块（可用 mkForce 禁用单个）
{ lib, config, ... }:
let
  cfg = config.mySystem.hardware;
in
{
  imports = [
    ./bluetooth.nix
    ./audio.nix
    ./network.nix
    ./mcu.nix
    ./nvidia-base.nix
  ];

  config = lib.mkIf cfg.enable {
    mySystem.hardware.audio.enable = lib.mkDefault true;
    mySystem.hardware.bluetooth.enable = lib.mkDefault true;
    mySystem.hardware.network.enable = lib.mkDefault true;
    mySystem.hardware.mcu.enable = lib.mkDefault true;
    # nvidia 需要主机显式开启（WSL 不需要）

    # 硬件加速（Mesa/Vulkan 用户态驱动）：曾在 core 里无条件开启，
    # 但它是桌面/渲染相关的硬件能力而非系统基础——服务器不需要。
    # 挪到硬件域（与音频/蓝牙同级），只随 mySystem.hardware.enable 启用。
    hardware.graphics.enable = lib.mkDefault true;
  };
}
