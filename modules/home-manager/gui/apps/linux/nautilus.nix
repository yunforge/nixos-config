# Nautilus（GNOME Files）文件管理器
#
# 2026-11-14 起：右键「在终端中打开」随 Ghostty 一并移除（原实现依赖 Ghostty
# 自带的 nautilus-python 扩展与 NAUTILUS_4_EXTENSION_DIR 接线，见 git 历史）。
{
  lib,
  config,
  pkgs,
  ...
}:
let
  cfg = config.myHome.gui.apps.nautilus;
  guiCfg = config.myHome.gui;
in
{
  options.myHome.gui.apps.nautilus.enable = lib.mkOption {
    type = lib.types.bool;
    default = true;
    description = "启用 Nautilus（GNOME Files）文件管理器";
  };

  config = lib.mkIf (cfg.enable && guiCfg.enable) {
    home.packages = [
      pkgs.nautilus
    ];
  };
}
