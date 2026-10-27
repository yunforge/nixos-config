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
    # 两台外接屏（2026-10-26 起新增华为 SSN-24，原 4K ICD GX288UR 挪到 DP-3）。
    # niri 对未配位置的输出按输出名排序自动左右排布，DP-2 在左、DP-3 在右。
    desktop.monitors = [
      {
        # 4K@150Hz 主力屏，分数缩放 1.5（desktop.scale 由此派生，无需重复声明）。
        # EDID 首选模式是 4K60，须显式钉 150Hz。冷启动 EDID 自愈见 edid-reprobe.nix
        name = "DP-3";
        mode = "3840x2160@150.000";
        scale = 1.5;
        # 外接显示器走 DDC/CI 调亮度（本机 hardware.i2c.enable = true）
        ddc = true;
      }
      {
        # 24" 1080p（92 PPI），scale 1.5 而非 1.0：**必须与 DP-3 同值**。
        # xwayland-satellite 在混合缩放时按最小 scale 给所有 X11 应用
        # （日志原文 "choosing to give apps the smallest detected scale"），
        # DP-2 若留 1.0 会把 Xft.dpi 压到 96，微信/WPS/Logisim 在 4K 屏上
        # 全按 1x 渲染（字号 UI 明显偏小）。代价是这块屏有效空间 1280x720，
        # 观感上字比 1.0 大不少——这是换来 X11 应用正确的取舍。
        # EDID 首选即 1920x1080@60，无需钉模式（另有 75Hz 模式可用，未钉）
        name = "DP-2";
        scale = 1.5;
        ddc = true;
      }
    ];
    # 与 laptop 的真实差异：这台是游戏机，开 Steam
    desktop.steam.enable = true;
    # NVIDIA 由主机显式开启（hardware 域的聚合默认值不含它）
    hardware.nvidia.enable = true;
  };
}
