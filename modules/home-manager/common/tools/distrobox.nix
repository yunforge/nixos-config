# Distrobox 用户级配置
# 只做一件事：让容器的 home 与宿主分离（细节见 docs/environment.md「容器的开发环境」）。
#
# 背景：distrobox 默认把宿主 $HOME 当容器 home。于是宿主 HM 生成的
# ~/.config/fish 会被容器里的 fish 读到（引用了容器没装的 eza / zoxide / fnm），
# 反过来容器里 `pip install --user`、`cargo install` 写进 ~/.local/bin、
# ~/.cargo/bin 之后又出现在宿主 PATH 上，绕过 NixOS 的包管理。
# 设 container_home_prefix 后 HOME / XDG_* 全部指向 ~/.distrobox/<name>。
{
  lib,
  config,
  pkgs,
  ...
}:
let
  cfg = config.mengw.cli.tools.distrobox;
  cliCfg = config.mengw.cli;
in
{
  options.mengw.cli.tools.distrobox.enable = lib.mkOption {
    type = lib.types.bool;
    default = true;
    description = "启用 Distrobox 用户级配置（容器 home 与宿主隔离）";
  };

  config = lib.mkIf (cfg.enable && cliCfg.enable && pkgs.stdenv.hostPlatform.isLinux) {
    # distrobox / podman 由 modules/nixos/desktop/distrobox.nix 装（系统级），
    # 这里只要配置文件，故 package = null 避免在用户 profile 里再装一份。
    programs.distrobox = {
      enable = true;
      package = null;
      # 该键仅在 distrobox create 时被读取并写进容器配置，改完必须重建容器
      settings.container_home_prefix = "${config.home.homeDirectory}/.distrobox";
    };
  };
}
