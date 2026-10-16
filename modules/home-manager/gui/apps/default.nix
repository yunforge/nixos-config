# GUI 应用聚合入口
#
# apps/shared：跨平台 GUI 应用配置（Ghostty / VSCode）——macOS 也导入这层，
#   只负责「用户配置」（程序本体在 Linux 走 HM 的 programs.<name>，在 macOS
#   走 modules/darwin/gui.nix 的 Homebrew casks，两者在各自的平台层装）。
# apps/linux：Linux 专属 GUI 应用——只有工作站导入。
#
# 门控：mengw.gui.enable 控制本层，目录导入即生效，无中间层开关。
{ ... }:
{
  imports = [
    ./shared
    ./linux
  ];
}
