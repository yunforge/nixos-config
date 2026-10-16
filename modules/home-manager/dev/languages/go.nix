{
  lib,
  config,
  pkgs,
  ...
}:
let
  cfg = config.mengw.cli.dev.go;
  devCfg = config.mengw.dev;
in
{
  options.mengw.cli.dev.go.enable = lib.mkOption {
    type = lib.types.bool;
    default = true;
    description = "启用 Go 开发环境";
  };

  config = lib.mkIf (cfg.enable && devCfg.enable) {
    # Go 环境
    home.packages = with pkgs; [
      go
      gopls # go lsp
    ];
  };
}
