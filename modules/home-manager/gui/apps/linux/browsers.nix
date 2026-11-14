# 浏览器
{
  lib,
  config,
  pkgs,
  inputs,
  ...
}:
let
  cfg = config.myHome.gui.apps.browsers;
  guiCfg = config.myHome.gui;
in
{
  imports = [ inputs.zen-browser.homeModules.beta ];

  options.myHome.gui.apps.browsers.enable = lib.mkOption {
    type = lib.types.bool;
    default = true;
    description = "启用浏览器应用";
  };

  config = lib.mkIf (cfg.enable && guiCfg.enable) {
    # Microsoft Edge 已于 2026-11-14 移除（包、外观 activation、niri 窗口规则与
    # docs/quirks.md 的圆角条目一并删除）；浏览器快捷键 Mod+Shift+Return 现指向 Zen。
    #
    # Brave 已于 2026-11-03 从 nixpkgs 移除（维护者缺失 + 安全问题，硬 throw），
    # 本仓库不再声明它的包与默认关联；Brave 改在 ~/Apps 自行维护（自带 desktop
    # entry，MIME 关联也由它自己「设为默认」，仓库不再钉）。故这里不再列 brave、
    # 不再设 BROWSER=brave。
    #
    # Zen browser — Firefox-based, from the community flake (beta channel)。
    # 可执行文件为 zen-beta，niri 的 Mod+Shift+Return（浏览器）绑定指向它，
    # 见 niri/config/binds/apps.kdl。
    programs.zen-browser = {
      enable = true;
      setAsDefaultBrowser = false;
    };

  };
}
