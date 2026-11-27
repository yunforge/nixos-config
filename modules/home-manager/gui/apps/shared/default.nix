# 跨平台 GUI 应用配置
#
# 这层只管「用户配置」，软件安装按平台分开：
#   Linux：programs.<name> 由 HM 装包（本目录各叶子）
#   macOS：程序本体由 modules/darwin/gui.nix 的 Homebrew casks 安装，
#          HM 侧只保留启用与平台包选择（如 vscode 的 package = null）
{
  ...
}:
{
  imports = [
    ./vscode.nix
  ];
}
