# WSL 主机（仅 CLI/TUI）— wsl 角色
#
# 用户环境（Shell / 编辑器 / CLI·TUI / 语言工具链）由 wsl 角色的 HM 侧
# 给出；系统层不开桌面与硬件能力（均由 Windows 宿主管）。
{
  config,
  pkgs,
  lib,
  inputs,
  ...
}:
{
  imports = [
    inputs.nixos-wsl.nixosModules.default
    ./proxy.nix
  ];

  networking.hostName = "wsl";

  # WSL 容器模式，不需要 bootloader
  boot.isContainer = true;

  # WSL 默认用户（由 mySystem.primaryUser 派生，与其它主机的接线同源）
  wsl.enable = true;
  wsl.defaultUser = config.mySystem.primaryUser;

  # 根文件系统
  fileSystems."/" = {
    device = "/dev/disk/by-label/nixos";
    fsType = "ext4";
  };

  # magpie（各 AI agent 的模型选择器）：无图形会话的主机用纯终端版
  # （nogui/CGO_ENABLED=0，闭包 17 MiB）；desktop/laptop 由 GUI 层装带托盘的
  # 桌面版（链接 WebKitGTK，闭包 847 MiB，见 gui/apps/linux/utilities.nix）。
  environment.systemPackages = with pkgs; [ magpie-cli ];
}
