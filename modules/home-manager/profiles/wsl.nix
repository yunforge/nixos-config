# 角色配置：WSL（NixOS-WSL）
#
# 无 Linux 桌面会话，也不装 GUI 应用（WSLg 只承载零星 Windows 侧窗口，
# 本仓库不在 WSL 里跑 Linux GUI 应用）。公共 CLI/TUI 与语言工具链照常。
{
  lib,
  config,
  ...
}:
{
  config = {
    myHome.cli.enable = lib.mkDefault true;
    myHome.dev.enable = lib.mkDefault true;
    myHome.gui.enable = lib.mkDefault false;
    myHome.desktop.enable = lib.mkDefault false;
  };

  imports = [
    ../dev
    ../platform/linux.nix
  ];
}
