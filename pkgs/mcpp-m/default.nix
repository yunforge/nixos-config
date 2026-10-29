# mcpp —— C++23 模块优先的构建工具（上游 mcpp-community/mcpp）
#
# 一个命令覆盖五件事：构建系统（自动处理 import std / BMI 依赖）、构建插件、
# 包管理器（SemVer + lockfile + 包索引）、工具链管理（family@version 按需安装）、
# 运行时环境（沙箱 + 运行器）。装出来的命令是 `mcpp`。
#
# 包名为什么叫 mcpp-m：nixpkgs 里的 `mcpp` 是 Matsui 的 C 预处理器，与本品同名
# 不同物（Arch 的 mcpp-bin、brew 的 mcpp-m 也是因此改名）。这里沿用上游在其它
# 发行版的命名，避免与 nixpkgs 的同名属性硬碰。
#
# 为什么用预编译包：上游是纯自举的（用 C++23 modules 写自己，并由上一版 mcpp
# 构建自己），AUR 的源码包也得先拿 mcpp-bin 引导。nix 的干净构建环境里没有
# 初始 mcpp，源码构建这条路走不通，故直接取官方 release 的 bundle（上游只发
# linux-x86_64 / linux-aarch64 / macosx-arm64 三个平台）。
#
# 为什么还要包一层 wrapper：bundle 里的 bin/mcpp 虽是静态链接（macOS 侧只依赖
# /usr/lib/libSystem.B.dylib），但它按 install.sh 的 PREFIX 语义把「沙箱根」
# 解析成自己的上级目录（$PREFIX/bin/mcpp + $PREFIX/registry/），首次运行会往
# 那里播种 registry/bin/xlings、config.toml、cache/ 等。装进只读的 /nix/store
# 后这些写入必然失败（实测：bundle 目录 chmod a-w 后，只要 MCPP_HOME 指到别处
# 就能正常初始化），故 wrapper 把 MCPP_HOME 指到用户可写目录（默认 ~/.mcpp，
# 与上游 install.sh 一致），store 里的 bundle 退化为只读种子。
#
# 首次运行需联网：拉包索引 + 自举 patchelf、ninja 进 MCPP_HOME。国内慢就用
# `mcpp self config --mirror CN` 切 GitCode 镜像。升级不走 `mcpp self update`
# （本机这份在 store 里只读），改的还是这个文件：
#   1. 改 version；
#   2. 三个 hash 取自
#      https://github.com/mcpp-community/mcpp/releases/download/v<ver>/mcpp-<ver>-<asset>.tar.gz.sha256
#      （hex 转 SRI：nix hash convert --hash-algo sha256 --to sri <hex>）
#
# 附：bundle 自带的 xlings 会在首次运行后落到 $MCPP_HOME/registry/bin/xlings。
# 想用上游的短命令（mp / mbuild / mrun …共 30 个），跑
# `"$MCPP_HOME/registry/bin/xlings" install mcpp-short-cmd -y`。
{
  lib,
  stdenvNoCC,
  fetchurl,
  symlinkJoin,
  writeShellScriptBin,
}:
let
  version = "2026.10.29.1";

  # 上游只发这三个平台的预编译包；其余平台显式报错，别指望它悄悄退化到别的架构
  sources = {
    x86_64-linux = {
      asset = "linux-x86_64";
      hash = "sha256-fw6yDW9Da1WNmOCRbPFDxdCKLisDbbvFd1izj6AkAU8=";
    };
    aarch64-linux = {
      asset = "linux-aarch64";
      hash = "sha256-1WSYvYx5FBTWd2lhzAeZuRkLEw9jJA6W0xBMqOG9m3Q=";
    };
    aarch64-darwin = {
      asset = "macosx-arm64";
      hash = "sha256-bsiLxQ1ZEa+g5hKGRHmxwTnHklsive+yfcv4TXA2hO4=";
    };
  };

  source =
    sources.${stdenvNoCC.hostPlatform.system} or (throw ''
      mcpp-m: 上游未发布 ${stdenvNoCC.hostPlatform.system} 的预编译包
      可用平台：linux-x86_64 / linux-aarch64 / macosx-arm64
      见 https://github.com/mcpp-community/mcpp/releases
    '');

  # bundle 必须保持 bin/ 与 registry/ 同级（mcpp 以自身路径反推 PREFIX），故整体
  # 落在 libexec/ 下，再由 wrapper 暴露 $out/bin/mcpp——不能把 bin/mcpp 摊到顶层
  bundle = stdenvNoCC.mkDerivation {
    pname = "mcpp-m-bundle";
    inherit version;

    src = fetchurl {
      url = "https://github.com/mcpp-community/mcpp/releases/download/v${version}/mcpp-${version}-${source.asset}.tar.gz";
      inherit (source) hash;
    };

    # 预编译产物：不 configure / 不 build，也别让 stdenv 的 fixup 去动它。
    # 尤其不能 strip——macOS 侧 Mach-O 的 ad-hoc 签名靠原样保留才有效。
    dontConfigure = true;
    dontBuild = true;
    dontStrip = true;
    dontPatchELF = true;

    # tarball 里套了一层 mcpp-<ver>-<asset>/
    setSourceRoot = "sourceRoot=$(echo mcpp-*/)";

    installPhase = ''
      runHook preInstall
      mkdir -p $out/libexec
      cp -r bin registry LICENSE README.md $out/libexec/
      runHook postInstall
    '';
  };

  wrapper = writeShellScriptBin "mcpp" ''
    # 包体在 store 里只读，而 mcpp 的沙箱布局要写到 MCPP_HOME（理由见本文件顶部）
    if [ -z "''${MCPP_HOME:-}" ]; then
      export MCPP_HOME="''${HOME:?MCPP_HOME 与 HOME 均为空，无法确定 mcpp 沙箱目录}/.mcpp"
    fi
    exec ${bundle}/libexec/bin/mcpp "$@"
  '';
in
symlinkJoin {
  name = "mcpp-m-${version}";
  paths = [
    bundle
    wrapper
  ];

  meta = {
    description = "Modern C++23 module-first build tool, package manager, toolchain manager and runtime";
    longDescription = ''
      mcpp is a self-hosted C++23 build tool: `import std` and module interface
      units are handled out of the box, with an integrated package index,
      on-demand toolchains and per-build sandboxing.
    '';
    homepage = "https://github.com/mcpp-community/mcpp";
    changelog = "https://github.com/mcpp-community/mcpp/releases/tag/v${version}";
    license = lib.licenses.asl20;
    mainProgram = "mcpp";
    platforms = [
      "x86_64-linux"
      "aarch64-linux"
      "aarch64-darwin"
    ];
    sourceProvenance = with lib.sourceTypes; [ binaryNativeCode ];
  };
}
