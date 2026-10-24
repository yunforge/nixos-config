# Linux 桌面会话聚合入口
#
# 与 GUI 应用（apps/）分开：这里管的是「桌面会话本身」——窗口管理器、
# Shell、主题、亮/暗切换、MIME 关联与 Windows 应用接入。
# 输入法只在系统层接线（modules/nixos/desktop），HM 侧不托管文件。
# 仅工作站（desktop/laptop）导入；macOS / server / wsl 均不导入。
#
# 门控：myHome.desktop.enable 控制本层，目录导入即生效，无中间层开关。
{ ... }:
{
  imports = [
    ./niri
    ./themes
    ./mimeapps.nix
    ./winapps.nix
  ];
}
