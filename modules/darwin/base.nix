# macOS 基础配置（所有 Darwin 主机共享）
{
  config,
  pkgs,
  lib,
  inputs,
  ...
}:

{
  imports = [
    # Nix 设置 / 镜像源 / overlay 注入的平台无关部分（与 NixOS core 共享单一真源）
    ../shared/nix.nix
  ];

  # valgrind 在 darwin 上被标记为 broken（见 nixpkgs pkgs/by-name/va/valgrind），
  # 但 cpp.nix 开发环境无条件引入它，放行以允许 darwin 求值
  nixpkgs.config.problems.handlers.valgrind.broken = "warn";

  # 放行 Linux-only 包的评估（共享 shell 模块把 sysstat 等带进 darwin toplevel，
  # macbook 本机 rebuild 与 CI 对 darwin 的 dry-build 求值都会踩到平台守卫）
  nixpkgs.config.allowUnsupportedSystem = true;

  # 系统级包
  environment.systemPackages = with pkgs; [
    git
    wget
  ];

  # 键盘
  system.keyboard.enableKeyMapping = true;
  system.keyboard.remapCapsLockToControl = false;

  # 安全
  security.pam.services.sudo_local.touchIdAuth = true;

  system.stateVersion = 5;
}
