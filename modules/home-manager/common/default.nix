# 公共用户环境聚合入口（所有主机共享）
#
# 这一层是「跨平台公共配置」：Shell 与交互环境、编辑器、CLI/TUI 工具。
# 语言工具链在 dev/（单独分层，由角色决定是否安装），GUI 应用与桌面会话在
# gui/（由角色决定导入哪些子层）。
#
# 门控：mengw.cli.enable 控制本层（各叶子模块自己判断，见各自文件的
# `cliCfg.enable`）；单独关闭某个叶子（如 fish）用该叶子自己的 enable 选项。
{ ... }:
{
  imports = [
    ./shell
    ./editors
    ./tools
  ];
}
