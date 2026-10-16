# 平台适配：Linux
#
# 只放「在 Linux 上才成立、且与具体主机无关」的用户级适配。
# 工具自身的平台差异（如 cpp.nix 只在 Linux 装 perf-tools）由各叶子模块用
# lib.optionals stdenv.hostPlatform.isLinux 自行处理，不集中到这里。
{
  config,
  lib,
  pkgs,
  ...
}:
{
  config = lib.mkIf pkgs.stdenv.hostPlatform.isLinux {
    # 强制使用英文 XDG 用户目录名（不受系统 locale 影响）
    xdg.userDirs = {
      enable = true;
      documents = "${config.home.homeDirectory}/Documents";
      download = "${config.home.homeDirectory}/Downloads";
      music = "${config.home.homeDirectory}/Music";
      pictures = "${config.home.homeDirectory}/Pictures";
      videos = "${config.home.homeDirectory}/Videos";
    };
  };
}
