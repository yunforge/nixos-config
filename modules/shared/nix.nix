# Nix 与 nixpkgs 的平台无关默认值 —— NixOS 与 macOS 的单一真源
#
# 消费方：modules/nixos/core/default.nix、modules/darwin/base.nix。
# 两边此前各自维护一份镜像源/公钥/flakes 特性/allowUnfree/overlay 注入，
# 靠注释提醒人肉保持一致（core 侧注释「与 darwin 侧的镜像顺序保持一致」），
# 两份必然漂移，收口到这里；平台专属部分（NixOS 的 GC/trusted-users、
# darwin 的 valgrind 放行等）仍留在各自 base。
{ inputs, ... }:
{
  # 启用 Flakes 特性以及配套的新 nix 命令行工具
  nix.settings = {
    experimental-features = [
      "flakes"
      "nix-command"
    ];
    # 自动存储优化，定期优化存储以节省空间
    auto-optimise-store = true;
    # 镜像在前（国内加速）。cache.nixos.org 不在此列：nixpkgs 与 nix-darwin
    # 的 nix 模块都会 mkAfter 追加官方源并无条件提供其公钥（darwin 侧曾显式
    # 写出，实际求值出两条重复项），此处只声明增量，避免合并后重复。
    substituters = [
      "https://mirrors.tuna.tsinghua.edu.cn/nix-channels/store"
      "https://mirrors.ustc.edu.cn/nix-channels/store"
      "https://nix-community.cachix.org"
    ];
    trusted-public-keys = [
      "nix-community.cachix.org-1:mB9FSh9qf2dCimDSUo8Zy7bkj5bg+wLbWLCTCfOj2Wc="
    ];
  };

  # 允许非自由软件
  nixpkgs.config.allowUnfree = true;

  # NUR overlay + 自定义包 overlay（主题 / mcpp 等，清单见 overlays/default.nix）。
  # home-manager useGlobalPkgs=true 复用这份系统级实例，HM 侧无需重复注入。
  nixpkgs.overlays = [
    inputs.nur.overlays.default
    (import ../../overlays { inherit inputs; })
  ];
}
