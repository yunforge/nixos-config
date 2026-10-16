# Fcitx5 用户级配置
{
  lib,
  config,
  pkgs,
  ...
}:
let
  cfg = config.mengw.gui.fcitx5;
  desktopCfg = config.mengw.desktop;
in
{
  options.mengw.gui.fcitx5.enable = lib.mkOption {
    type = lib.types.bool;
    default = true;
    description = "启用 Fcitx5 用户级配置（Rime）";
  };

  config = lib.mkIf (cfg.enable && desktopCfg.enable) {
    # Rime 页大小补丁（default.custom.yaml）
    home.file.".local/share/fcitx5/rime/default.custom.yaml".text = ''
      patch:
        __include: wanxiang_suggested_default:/
        __patch:
          menu/page_size: 5
    '';
  };
}
