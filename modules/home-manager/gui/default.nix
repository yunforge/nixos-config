# GUI 用户层聚合入口
#
# 分层：
#   apps/shared/    跨平台 GUI 应用配置（VSCode）——MacBook 也导入这层
#   apps/linux/     Linux 专属 GUI 应用——仅工作站
#   desktop/linux/  Linux 桌面会话（Niri / Noctalia / 主题 / WinApps）
#
# 门控沿用既有约定：myHome.gui.enable 控制 apps 层，myHome.desktop.enable 控制
# desktop 层；目录导入即生效，无中间层开关。具体某个应用用该叶子自己的 enable。
#
# 注意：当前角色 profile 直接导入子目录（workstation 导 apps/shared + apps/linux
# + desktop/linux，macbook 只导 apps/shared，server / wsl 不导入），本文件目前
# 不在任何导入链上，保留为将来统一入口。
{ ... }:
{
  imports = [
    ./apps
    ./desktop/linux
  ];
}
