# 游戏工具（Steam 客户端由系统模块 modules/nixos/desktop/steam.nix 提供）
{
  lib,
  config,
  pkgs,
  ...
}:
let
  cfg = config.mengw.gui.apps.steam;
  guiCfg = config.mengw.gui;
in
{
  options.mengw.gui.apps.steam.enable = lib.mkOption {
    type = lib.types.bool;
    default = true;
    description = "启用游戏工具（MangoHud、GameMode、Gamescope 等）";
  };

  config = lib.mkIf (cfg.enable && guiCfg.enable) {
    home.packages = with pkgs; [
      mangohud # 独立性能监控（非 Steam 原生应用可用 mangohud <app>）
      gamemode # gamemoderun 提频调用（原生应用）
      gamescope # 独立合成器（gamescope -- <app>）
      steamguard-cli # Steam 2FA 验证码 CLI
    ];
  };
}
