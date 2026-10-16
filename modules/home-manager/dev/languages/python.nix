{
  lib,
  config,
  pkgs,
  ...
}:
let
  cfg = config.mengw.cli.dev.python;
  devCfg = config.mengw.dev;
in
{
  options.mengw.cli.dev.python.enable = lib.mkOption {
    type = lib.types.bool;
    default = true;
    description = "启用 Python 开发环境";
  };

  config = lib.mkIf (cfg.enable && devCfg.enable) {
    # Python 环境
    home.packages = with pkgs; [
      # 解释器与下面的包集必须同源，否则 PATH 里的 python3 与 site-packages 版本错配，
      # 导致 import requests 失败。统一跟随 nixpkgs 默认 python3，升级 flake 时整体平移。
      python3

      # 现代 Python 包管理工具
      uv # 极速 Python 包和项目管理工具（替代 pip/poetry）
      python3Packages.pip # 传统包管理器（兼容性）

      # Python 开发工具
      virtualenv # 虚拟环境管理
      black # 代码格式化工具
      isort # import 排序工具
      ruff # 超快速的 Python linter
      python3Packages.huggingface-hub # Huggingface 下载工具

      # Python 类型检查
      mypy # 静态类型检查器

      # Python 测试工具
      python3Packages.pytest # 测试框架
      python3Packages.pytest-cov # pytest 覆盖率插件
      python3Packages.pytest-asyncio # 异步测试支持

      # Python 调试工具
      python3Packages.ipdb # 增强的 Python 调试器

      # 代码质量分析
      pylint # Python 代码分析工具
      bandit # 安全漏洞扫描工具

      # 文档生成
      mkdocs # 现代化文档生成工具
      python3Packages.mkdocs-material # Material 主题

      # LSP 服务器
      python3Packages.python-lsp-server # python lsp
    ];
  };
}
