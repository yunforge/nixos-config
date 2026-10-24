# 角色配置（系统层）：WSL（NixOS-WSL）
#
# 与工作站的区别：无桌面、无硬件能力（WSL 容器不直接管蓝牙 / 音频 / WiFi，
# 这些都由 Windows 宿主管）——两个开关保持 mkEnableOption 默认 false，不在此
# 重复声明。保留代理：WSL2 容器需要探测宿主代理地址（hosts/wsl/proxy.nix），
# autoUpgrade 才能正常拉 flake 输入。
{ lib, ... }:
{
  # WSL 特有：core 的 bootloader / 内核配置在 boot.isContainer=true 时会自动跳过
  # （core 内的 lib.mkIf (!config.boot.isContainer) 已处理，此处不重复）
  mySystem.proxy.enable = lib.mkDefault true;
}
