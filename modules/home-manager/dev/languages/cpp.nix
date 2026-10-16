{
  lib,
  config,
  pkgs,
  ...
}:
let
  cfg = config.mengw.cli.dev.cpp;
  devCfg = config.mengw.dev;
in
{
  options.mengw.cli.dev.cpp.enable = lib.mkOption {
    type = lib.types.bool;
    default = true;
    description = "启用 C/C++ 开发环境";
  };

  config = lib.mkIf (cfg.enable && devCfg.enable) {
    # C/C++ 开发环境
    home.packages =
      with pkgs;
      [
        # 编译器工具链（只用 clang，避免与 gcc 冲突）
        clang # c/c++ lsp
        cmake # 跨平台构建系统生成器
        cmake-language-server # cmake lsp
        gnumake
        ninja # 快速构建工具

        # C++ 包管理器和依赖管理
        vcpkg # C++ 包管理器
        # C++23 模块优先的构建/包/工具链管理器（首次运行会联网初始化 ~/.mcpp）。
        # 仓库自打包，经 overlays/default.nix 注入（预编译 bundle + MCPP_HOME
        # wrapper，理由见 pkgs/mcpp-m 顶部）。名字不能省成 `mcpp`：nixpkgs 的
        # mcpp 是 Matsui 的 C 预处理器，同名不同物。
        mcpp-m
        ccache # 编译缓存，加速重复编译

        # 调试和分析工具
        lldb # LLVM 调试器
        valgrind # 内存泄漏和性能分析工具

        # 代码质量和静态分析
        cppcheck # C++ 静态分析工具
        clang-tools # 包含 clang-format, clang-tidy, clangd

        # 构建依赖管理
        pkg-config # 编译时依赖配置工具
      ]
      ++ lib.optionals pkgs.stdenv.hostPlatform.isLinux (
        with pkgs;
        [
          # Linux 专属性能分析工具
          perf-tools # Linux 性能分析工具
          strace # 系统调用追踪
          # ltrace # 库调用追踪
          # ⚠️ 暂注释：nixpkgs 升到 GCC 16 后其测试套件误判失败（产物本身没问题），
          # 上游 nixpkgs#569695 修复后取消注释。根因与移除条件见 docs/quirks.md。
        ]
      );
  };
}
