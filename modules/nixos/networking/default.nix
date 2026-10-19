# 网络相关模块聚合
{ ... }:
{
  imports = [
    ./proxy.nix
    ./proxy-vm.nix
    ./tailscale.nix
  ];
}
