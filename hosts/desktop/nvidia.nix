# NVIDIA 驱动 — RTX 3060Ti
# 公共基础在 modules/nixos/hardware/nvidia-base.nix（经 hardware 域聚合进入
# 所有主机），本文件只写这台主机的差异。
{ config, ... }:

{
  # 不覆盖自定义 EDID 固件（drm.edid_firmware）：固件 EDID 会在显示器断电、
  # 真实 EDID 读取失败时顶上，连接器始终显示 connected，驱动从不登记断开 →
  # 上电后不自动重训练 DP 链路 → 黑屏。不覆盖即可恢复正常的断开/重连流程，
  # 显示器物理断电再上电后自动恢复，150Hz 亦由显示器 EDID 原生声明正常工作。
  boot.kernelParams = [
    # 完全禁用动态电源管理。即使设为 0x01（细粒度模式），显示器断开/
    # 休眠后 DP 链路唤醒时 GPU 仍无法正确重新训练 DP 链路，导致黑屏。
    # 桌面插电平台功耗差异可忽略，稳定性优先。
    # 放在主机级而非 nvidia-base：该参数会覆盖 finegrained 经 modprobe.d 注入的
    # 0x02（内核 cmdline 优先级更高），对 PRIME offload 笔记本是有害的。
    "nvidia.NVreg_DynamicPowerManagement=0x00"
    # 不用 video= 强制模式：video=DP-2:3840x2160@150 会创建 user-defined 模式，
    # 显示器唤醒时被 NVIDIA 拒绝报 "User-defined mode not supported" → 黑屏。
    # 显示器 EDID 的 DisplayID 块已原生声明 3840x2160@150Hz(1329MHz)，
    # 无需强制即可使用。也不使用 e 标志强制输出，否则会阻止连接器热插拔事件，
    # 物理断电再上电后 DP 链路无法重新训练 → 黑屏。
    # 禁止内核 VT 控制台超时熄屏，防止触发不必要的 DPMS 状态切换
    "consoleblank=0"
  ];

  # 桌面平台专属: G-Sync（VRR 的 __GL_VRR_ALLOWED=1 由 nvidia-base 统一设置）
  environment.variables = {
    __GL_GSYNC_ALLOWED = "1";
  };

  hardware.nvidia = {
    # 当前架构可用的最新版本 - 稳定分支（电源管理 base 已开）
    package = config.boot.kernelPackages.nvidiaPackages.stable;
  };
}
