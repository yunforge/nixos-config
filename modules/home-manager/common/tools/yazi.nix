# Yazi — 终端文件管理器
# 主题用 yazi 自带的默认 flavor（Noctalia 不再统一渲染各应用主题）。
{
  lib,
  config,
  pkgs,
  ...
}:
let
  cfg = config.myHome.cli.tools.yazi;
  cliCfg = config.myHome.cli;
in
{
  options.myHome.cli.tools.yazi.enable = lib.mkOption {
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
      # 终端换 Konsole（2026-11-14）后：Konsole 稳定版支持 sixel、kitty 图形协议
      # 残缺；yazi 的驱动选择按终端 brand 走，它在 Konsole 下能否走图形协议我没
      # 验证。ueberzugpp 作为无图形协议可用时的兜底（nixpkgs 的 yazi wrapper 不带
      # 它，图片会空白），所以两者都留着。
      extraPackages = lib.optional pkgs.stdenv.hostPlatform.isLinux pkgs.ueberzugpp;
    };
  };
}
