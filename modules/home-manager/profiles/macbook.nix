# 角色配置：MacBook（nix-darwin + Home Manager）
#
# 组合关系：
#   公共用户环境（common：shell / 编辑器 / CLI·TUI 工具，与 Linux 同一份）
#   + 语言工具链（dev：与工作站同一份；Linux 专属工具由各叶子模块自行过滤）
#   + 跨平台 GUI 应用配置（ghostty 的配置 / vscode 的启用）
#   + darwin 平台适配
#
# 明确不导入 gui/apps/linux 与 gui/desktop/linux：前者是 Linux 专属 GUI 应用，
# 后者是 Linux 桌面会话（Niri/Noctalia）。macOS 侧的 GUI 软件安装与系统设置
# 由 modules/darwin（Homebrew casks + system.defaults）管理，与用户层配置分离。
{
  lib,
  config,
  ...
}:
{
  config = {
    myHome.cli.enable = lib.mkDefault true;
    myHome.dev.enable = lib.mkDefault true;
    # 启用「跨平台 GUI 应用配置」这层（ghostty 配置、vscode），
    # 但不启用 Linux 专属 GUI 应用与 Linux 桌面会话
    myHome.gui.enable = lib.mkDefault true;
    myHome.desktop.enable = lib.mkDefault false;
  };

  imports = [
    ../dev
    ../gui/apps/shared
    ../platform/darwin.nix
  ];
}
