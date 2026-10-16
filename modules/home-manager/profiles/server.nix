# 角色配置：NixOS 服务器
#
# 与工作站的区别：无桌面、无 GUI 应用；用户环境只保留公共 CLI/TUI，
# 语言工具链按需启用（默认仍提供，以便在服务器上直接排查/构建代码；
# 若某台服务器只跑服务，可在我System 或主机里 mkForce 关掉 mengw.dev.enable）。
{
  lib,
  config,
  ...
}:
{
  config = {
    # 服务器只要 CLI/TUI 与（可选的）开发工具链；明确不启用 GUI 与桌面会话
    mengw.cli.enable = lib.mkDefault true;
    mengw.dev.enable = lib.mkDefault true;
    mengw.gui.enable = lib.mkDefault false;
    mengw.desktop.enable = lib.mkDefault false;
  };

  imports = [
    ../common
    ../dev
    ../platform/linux.nix
  ];
}
