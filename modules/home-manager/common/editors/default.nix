# 编辑器配置
# 门控：目录导入即生效（mengw.cli.enable 控制整个 CLI 层），无中间层开关；
# 单独关闭某个叶子（如 neovim）用该叶子自己的 enable 选项。
{
  imports = [
    ./neovim.nix
  ];
}
