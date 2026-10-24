# Linux 专属 GUI 应用聚合
#
# 所有应用统一由 Home Manager 管理（home.packages）。
# 门控：myHome.gui.enable 控制整个 GUI 层，目录导入即生效；
# 单独关闭某个应用用该叶子自己的 enable 选项。
{ ... }:
{
  imports = [
    ./browsers.nix
    ./communication.nix
    ./media.nix
    ./mpv.nix
    ./productivity.nix
    ./steam.nix
    ./development.nix
    ./embedded.nix
    ./terminal.nix
    ./utilities.nix
    ./pot.nix
  ];
}
