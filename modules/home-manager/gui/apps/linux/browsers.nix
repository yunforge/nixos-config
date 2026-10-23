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
    # 默认浏览器是 Brave：MIME 关联在 gui/desktop/linux/mimeapps.nix 声明，
    # 这里只补命令行侧（xdg-open / webbrowser 等读 BROWSER）。
    home.sessionVariables.BROWSER = "brave";
    # Zen browser — Firefox-based, from the community flake (beta channel).
    # 保持非默认：该选项会写 BROWSER=zen-beta 并抢注 http(s)/text/html。
    programs.zen-browser = {
      enable = true;
      setAsDefaultBrowser = false;
    };

  };
}
