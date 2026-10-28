{
  lib,
  config,
  pkgs,
  ...
}:
let
  cfg = config.myHome.cli.dev.go;
  devCfg = config.myHome.dev;
in
{
  options.myHome.cli.dev.go.enable = lib.mkOption {
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

    # 默认 GOPATH 是 ~/go，会在家目录顶层生成目录；改到 ~/Apps/go，
    # 模块缓存（pkg/mod）与 go install 的二进制（bin）都收在它下面。
    home.sessionVariables.GOPATH = "${config.home.homeDirectory}/Apps/go";
    home.sessionPath = [ "${config.home.homeDirectory}/Apps/go/bin" ];
  };
}
