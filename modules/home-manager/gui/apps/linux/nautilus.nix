# Nautilus（GNOME Files）集成
#
# 右键文件夹（或空白处）直接开 Ghostty，入口在一级菜单，由 Ghostty 自带的
# Nautilus 扩展（share/nautilus-python/extensions/ghostty.py）提供：
# get_file_items 处理选中的文件夹（选文件时取其父目录），get_background_items
# 处理空白处。本模块只负责让 Nautilus 加载它。
#
# 接线：扩展由 nautilus-python 加载，而 Nautilus 只扫编译期那一个扩展目录；
# nixpkgs 给 nautilus 打了读 NAUTILUS_4_EXTENSION_DIR 的补丁。这里指向 HM
# profile 的 lib/nautilus/extensions-4 —— buildEnv 已把 nautilus-python 的
# libnautilus-python.so 与 nautilus 自带的属性页扩展合并到同一目录，指向单个
# 包会漏掉其余扩展。扩展脚本本身在 ghostty 包的 share/nautilus-python/extensions，
# nautilus-python 沿 XDG_DATA_DIRS 找到它，不需要额外 pathsToLink。
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
    description = "启用 Nautilus（GNOME Files）及其右键开终端集成";
  };

  config = lib.mkIf (cfg.enable && guiCfg.enable) {
    home.packages = [
      pkgs.nautilus
      pkgs.nautilus-python
    ];

    # Nautilus 只认编译期那一个扩展目录，nixpkgs 的补丁允许用环境变量覆盖。
    home.sessionVariables.NAUTILUS_4_EXTENSION_DIR = "${config.home.profileDirectory}/lib/nautilus/extensions-4";
  };
}
