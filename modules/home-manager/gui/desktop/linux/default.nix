# Linux 桌面会话聚合入口
#
# 与 GUI 应用（apps/）分开：这里管的是「桌面会话本身」——窗口管理器、
# Shell、主题、亮/暗切换、输入法、MIME 关联与 Windows 应用接入。
# 仅工作站（desktop/laptop）导入；macOS / server / wsl 均不导入。
#
# 门控：mengw.desktop.enable 控制本层，目录导入即生效，无中间层开关。
{ ... }:
{
  imports = [
    ./niri
    ./themes
    ./fcitx5.nix
    ./mimeapps.nix
    ./winapps.nix
  ];
}
