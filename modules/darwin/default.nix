# macOS (nix-darwin) 模块
{ lib, config, ... }:
let
  cfg = config.mySystem.darwin;
in
{
  options.mySystem.darwin.enable = lib.mkOption {
    type = lib.types.bool;
    default = true;
    description = "启用 macOS (nix-darwin) 模块";
  };

  imports = [
    # macOS 共享层（与 NixOS 侧「共享配置都在 modules/」的约定对齐）：
    # nix 设置、系统级包、用户声明
    ./base.nix
    ./users.nix
    # GUI 管理（系统默认值 + Homebrew casks），由上方 enable 开关控制
    ./gui.nix
  ];
}
