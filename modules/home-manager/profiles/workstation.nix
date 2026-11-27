# 角色配置：Linux 工作站（NixOS PC / 笔记本）
#
# 组合关系（详见 docs/architecture.md）：
#   公共用户环境（common：shell / 编辑器 / CLI·TUI 工具）
#   + 语言工具链（dev）
#   + 跨平台 GUI 应用（vscode）
#   + Linux 专属 GUI 应用（浏览器 / 通讯 / 媒体 / 开发 / 嵌入式 …）
#   + Linux 桌面会话（Niri / Noctalia / 主题 / WinApps）
#
# 主机（hosts/desktop、hosts/laptop）不再自己拼这套组合，只声明硬件与显示器
# 等真实差异。服务器 / WSL / MacBook 不导入本文件，因此不会被动继承工作站能力。
{
  lib,
  osConfig,
  ...
}:
{
  # CLI/TUI、开发工具链与 GUI 应用独立于本机是否提供桌面会话。
  config = {
    myHome.cli.enable = lib.mkDefault true;
    myHome.dev.enable = lib.mkDefault true;
    myHome.gui.enable = lib.mkDefault true;
    myHome.desktop.enable = lib.mkDefault osConfig.mySystem.desktop.enable;
  };

  imports = [
    ../dev
    ../gui
    ../platform/linux.nix
  ];
}
