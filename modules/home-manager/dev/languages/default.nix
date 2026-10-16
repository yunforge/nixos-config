# 开发工具配置
# 门控：目录导入即生效（mengw.cli.enable 控制整个 CLI 层），无中间层开关；
# 单独关闭某个语言环境（如 python）用该叶子自己的 enable 选项。
{
  imports = [
    ./node.nix
    ./python.nix
    ./rust.nix
    ./go.nix
    ./cpp.nix
    ./others.nix
  ];
}
