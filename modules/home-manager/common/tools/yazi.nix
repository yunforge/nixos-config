# Yazi — 终端文件管理器
# 主题由 Noctalia 统一管理（community "yazi" 模板），不再 vendored 上游 flavor。
{
  lib,
  config,
  pkgs,
  ...
}:
let
  cfg = config.mengw.cli.tools.yazi;
  cliCfg = config.mengw.cli;
in
{
  options.mengw.cli.tools.yazi.enable = lib.mkOption {
    type = lib.types.bool;
    default = true;
    description = "启用 Yazi 终端文件管理器";
  };

  config = lib.mkIf (cfg.enable && cliCfg.enable) {
    programs.yazi = {
      enable = true;
      enableFishIntegration = true;
      shellWrapperName = "y";
      # Yazi 26 移除了 yazi.toml 的顶层排序键，必须放进 [mgr] 段，
      # 顶层的 sort_by 会被当成 opener 表的键名解析，报 "must be 1-20 characters in kebab-case"
      settings = {
        mgr = {
          sort_by = "natural";
          sort_sensitive = true;
        };
        preview = {
          tab_size = 2;
          max_width = 2000;
          max_height = 2000;
        };
      };
      # ghostty 走 Kitty 图形协议（yazi 的驱动选择按终端 brand 走，它认不认 ghostty
      # 这一项我没验证）；ueberzugpp 作为 GNOME 终端 / WSLg 等无图形协议终端的兜底
      # （nixpkgs 的 yazi wrapper 不带它，图片会空白），所以两者都留着。
      extraPackages = lib.optional pkgs.stdenv.hostPlatform.isLinux pkgs.ueberzugpp;
      # 主题由 Noctalia 统一管理（gui/desktop/linux/niri/noctalia.nix 启用 community "yazi" 模板）：
      # Noctalia 写到 ~/.config/yazi/flavors/noctalia.yazi/{flavor.toml,tmtheme.xml}，其 apply.sh
      # 会把本段改成 dark/light = "noctalia"。这里先写好最终值，apply.sh 检测到已是目标值即不写。
      theme = {
        flavor = {
          light = "noctalia";
          dark = "noctalia";
        };
      };
    };
  };
}
