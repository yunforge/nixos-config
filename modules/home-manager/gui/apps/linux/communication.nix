# 通讯工具
{
  lib,
  config,
  pkgs,
  myLib,
  ...
}:
let
  cfg = config.myHome.gui.apps.communication;
  guiCfg = config.myHome.gui;

  wechat-scaled = myLib.wrapQtXWayland {
    inherit pkgs;
    pkg = pkgs.wechat;
  };
in
{
  options.myHome.gui.apps.communication.enable = lib.mkOption {
    type = lib.types.bool;
    default = true;
    description = "启用通讯工具";
  };

  config = lib.mkIf (cfg.enable && guiCfg.enable) {
    home.packages = with pkgs; [
      discord
      telegram-desktop
      wechat-scaled # 微信
      wemeet # 腾讯会议
      qq
    ];
  };
}
