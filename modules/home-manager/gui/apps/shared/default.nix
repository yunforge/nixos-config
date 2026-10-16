# 跨平台 GUI 应用配置
#
# 这层只管「用户配置」，软件安装按平台分开：
#   Linux：programs.<name> 由 HM 装包（本目录各叶子）
#   macOS：程序本体由 modules/darwin/gui.nix 的 Homebrew casks 安装，
#          用户配置仍由这里的 HM 模块生成（如 ghostty 的 ~/.config/ghostty）
{
  ...
}:
{
  imports = [
    ./ghostty.nix
    ./vscode.nix
  ];
}
