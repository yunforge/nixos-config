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
    # Brave 已于 2026-11-03 从 nixpkgs 移除（维护者缺失 + 安全问题，硬 throw），
    # 本仓库不再声明它的包与默认关联；Brave 改在 ~/Apps 自行维护（自带 desktop
    # entry，MIME 关联也由它自己「设为默认」，仓库不再钉）。故这里不再列 brave、
    # 不再设 BROWSER=brave。
    #
    # Zen browser — Firefox-based, from the community flake (beta channel).
    programs.zen-browser = {
      enable = true;
      setAsDefaultBrowser = false;
    };

  };
}
