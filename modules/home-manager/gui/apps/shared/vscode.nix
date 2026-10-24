# VSCode 编辑器（跨平台配置层）
#
# 跨平台共享边界：本模块只负责「启用与配置」。
#   Linux：程序由 HM 的 programs.vscode 安装
#   macOS：程序由 modules/darwin/gui.nix 的 Homebrew cask（visual-studio-code）
#          安装，本模块不重复装包。
#
# 扩展策略：不再用 nix 管理扩展（programs.vscode.profiles.extensions）。
#
# 背景：之前 mutableExtensionsDir = true，与 VSCode 自持的
# extensions.json/.obsolete 索引相互打架 —— flake update 重建后扩展 store path
# 变更、索引刷新时机又受"VSCode 是否在运行"影响，导致 nix 管理的插件反复丢失。
# 现改由 VSCode 内置 Settings Sync（登录账号云同步）管理扩展，此处仅安装 code 本体。
{
  lib,
  config,
  pkgs,
  ...
}:
let
  cfg = config.myHome.gui.vscode;
  guiCfg = config.myHome.gui;
in
{
  options.myHome.gui.vscode.enable = lib.mkOption {
    type = lib.types.bool;
    default = true;
    description = "启用 VSCode 编辑器（macOS 上程序走 Homebrew cask）";
  };

  config = lib.mkIf (cfg.enable && guiCfg.enable) {
    programs.vscode = {
      enable = true;
      # macOS 由 Homebrew cask 安装，HM 只管用户配置（与 ghostty 同一模式）
      package = lib.mkIf (!pkgs.stdenv.hostPlatform.isLinux) null;
    };
  };
}
