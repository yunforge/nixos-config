# 角色配置：Linux 工作站（NixOS PC / 笔记本）
#
# 组合关系（详见 docs/architecture.md）：
#   公共用户环境（common：shell / 编辑器 / CLI·TUI 工具）
#   + 语言工具链（dev）
#   + 跨平台 GUI 应用（ghostty / vscode）
#   + Linux 专属 GUI 应用（浏览器 / 通讯 / 媒体 / 开发 / 嵌入式 …）
#   + Linux 桌面会话（Niri / Noctalia / 主题 / 输入法 / MIME / WinApps）
#
# 主机（hosts/desktop、hosts/laptop）不再自己拼这套组合，只声明硬件与显示器
# 等真实差异。服务器 / WSL / MacBook 不导入本文件，因此不会被动继承工作站能力。
{
  lib,
  config,
  ...
}:
let
  inherit (config.myHome)
    cli
    dev
    gui
    desktop
    ;
in
{
  # 工作站默认全开：CLI/TUI、完整语言工具链、GUI 应用与 Linux 桌面会话。
  # 主机可用 mkForce 关单项（如某台暂时不装桌面）。
  config = {
    myHome.cli.enable = lib.mkDefault true;
    myHome.dev.enable = lib.mkDefault true;
    myHome.gui.enable = lib.mkDefault true;
    myHome.desktop.enable = lib.mkDefault true;
    # 每日 AI 签到：systemd user timer 每天 09:07 跑 ~/checkin/run.sh。
    # 数据目录 ~/checkin 由脚本侧管理，这里只管定时拉起。
    myHome.cli.tools.daily-checkin.enable = lib.mkDefault true;
  };

  imports = [
    ../common
    ../dev
    ../gui/apps/shared
    ../gui/apps/linux
    ../gui/desktop/linux
    ../platform/linux.nix
  ];
}
