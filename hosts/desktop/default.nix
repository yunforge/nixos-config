# NixOS 台式机（Niri 桌面）— workstation 角色
#
# 系统能力（硬件 / 桌面 / 虚拟化 / 代理）与用户环境（CLI/TUI / 工具链 /
# GUI 应用 / 桌面会话）都由 workstation 角色模块给出默认值；
# 本文件只声明这台主机的真实差异：硬件、显示器与主机专属修复。
{
  config,
  pkgs,
  lib,
  ...
}:
{
  imports = [
    ./hardware.nix
    ./nvidia.nix
    ./edid-reprobe.nix
  ];

  networking.hostName = "desktop";
  hardware.i2c.enable = true;

  mySystem = {
    # 4K@150Hz 显示器，分数缩放 1.5（desktop.scale 由此派生，无需重复声明）
    desktop.monitors = [
      {
        name = "DP-2";
        mode = "3840x2160@150.000";
        scale = 1.5;
        # 外接显示器走 DDC/CI 调亮度（本机 hardware.i2c.enable = true）
        ddc = true;
      }
    ];
    # 与 laptop 的真实差异：这台是游戏机，开 Steam
    desktop.steam.enable = true;
    # NVIDIA 由主机显式开启（hardware 域的聚合默认值不含它）
    hardware.nvidia.enable = true;
  };
}
