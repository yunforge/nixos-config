# 语言工具链聚合入口
#
# 与普通 CLI 分层（不再挂在 cli/ 下）：是否安装完整工具链由角色决定
# （workstation / server / wsl / macbook 各自决定 myHome.dev.enable，
# 见 modules/home-manager/profiles/）。
#
# 门控：myHome.dev.enable 控制本层；语言内的 Linux 专属工具由各叶子模块用
# lib.optionals stdenv.hostPlatform.isLinux 自行过滤，共用本层即可跨平台。
{
  lib,
  config,
  ...
}:
let
  devCfg = config.myHome.dev;
in
{
  imports = [
    ./languages/node.nix
    ./languages/python.nix
    ./languages/rust.nix
    ./languages/go.nix
    ./languages/cpp.nix
    ./languages/others.nix
  ];

  config = lib.mkIf devCfg.enable { };
}
