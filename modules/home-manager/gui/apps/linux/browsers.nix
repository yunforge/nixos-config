# 浏览器
{
  lib,
  config,
  pkgs,
  inputs,
  ...
}:
let
  cfg = config.mengw.gui.apps.browsers;
  guiCfg = config.mengw.gui;
in
{
  imports = [ inputs.zen-browser.homeModules.beta ];

  options.mengw.gui.apps.browsers.enable = lib.mkOption {
    type = lib.types.bool;
    default = true;
    description = "启用浏览器应用";
  };

  config = lib.mkIf (cfg.enable && guiCfg.enable) {
    home.packages = with pkgs; [
      brave
    ];
    # Zen browser — Firefox-based, from the community flake (beta channel).
    programs.zen-browser = {
      enable = true;
      setAsDefaultBrowser = true;
    };

  };
}
