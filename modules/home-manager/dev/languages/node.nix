{
  lib,
  config,
  pkgs,
  ...
}:
let
  cfg = config.myHome.cli.dev.node;
  devCfg = config.myHome.dev;

  # nixpkgs 2026-11-09 起给 cargo-setup-hook 加了 cargoUseSystemLibs，无条件
  # 导出 ZSTD_SYS_USE_PKG_CONFIG=1，让 zstd-sys 的 build.rs 改走 pkg-config
  # 探测系统 libzstd；而 fnm 的 nativeBuildInputs 只有 installShellFiles，
  # 既无 pkg-config 也无 zstd，于是 build.rs 直接 panic（cache.nixos.org 上
  # 该产物同样 404，Hydra 也编不出来）。关掉这个 hook，zstd-sys 照旧编译
  # 随包 vendored 的 zstd/lib——fnm 的 Cargo.lock 里只有 zstd 一个走
  # system-lib 的 crate，其余（libz/openssl/libgit2/libssh2/sqlite/jemalloc）
  # 都不在依赖图里，故整包关掉等价于回归前的行为。
  # 根因与移除条件见 docs/quirks.md。
  fnmFixed = pkgs.fnm.overrideAttrs (_old: {
    dontCargoUseSystemLibs = true;
  });
in
{
  options.myHome.cli.dev.node.enable = lib.mkOption {
    type = lib.types.bool;
    default = true;
    description = "启用 Node.js 开发环境";
  };

  config = lib.mkIf (cfg.enable && devCfg.enable) {
    # Node.js 环境（版本交给 fnm，shell 初始化见 common/shell/fish.nix）
    home.packages = with pkgs; [
      fnmFixed
      yarn
      pnpm
      typescript-language-server # typescript/js/tsx/jsx lsp
      prettier # JavaScript/TypeScript/JSON/Markdown/YAML 格式化器
    ];
  };
}
