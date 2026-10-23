# macOS 用户配置
{ config, pkgs, ... }:

let
  # 用户名在 darwin 侧只出现这一次：nix-darwin 的 system.primaryUser 是
  # homebrew / system.defaults 等选项读的单一来源，home 路径与 flake.nix 的
  # home-manager.users 均由它派生（与 NixOS 侧 mySystem.primaryUser 同构）。
  primaryUser = "yunforge";
in
{
  # macOS 用户主要通过 System Preferences 管理
  # nix-darwin 不会实际创建用户，这里声明 home 路径供 home-manager 等模块使用
  users.users.${primaryUser} = {
    home = "/Users/${primaryUser}";
  };

  # 新版 nix-darwin 要求显式指定 primaryUser，用于 homebrew、system.defaults 等选项
  system.primaryUser = primaryUser;

  programs.fish.enable = true;
}
