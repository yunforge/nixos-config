# WiFi 和网络管理
{
  lib,
  config,
  pkgs,
  ...
}:
let
  cfg = config.mySystem.hardware;
in
{
  options.mySystem.hardware.network.enable = lib.mkEnableOption "WiFi 和网络管理（NetworkManager + iwd）";

  config = lib.mkIf (cfg.enable && cfg.network.enable) {
    networking.wireless.iwd.enable = true;
    # 启用 NetworkManager
    networking.networkmanager.enable = true;
    networking.networkmanager.wifi.backend = "iwd";

    # 路由器通过 RA(RDNSS) 把 fe80::100 通告为 IPv6 DNS，但实测不响应链路本地 53 端口；
    # tailscaled 接管 resolv.conf 后会把 [192.168.2.1, fe80::100%eno1] 都当转发上游，
    # 每个查询对 v6 那一路打一条 5s 超时 err（3 天 3.3 万条，解析本身走 v4 恒 7-10ms）。
    # 忽略 v6 自动下发的 DNS（v4 DHCP 的 192.168.2.1 不受影响），见 docs/quirks.md。
    networking.networkmanager.connectionConfig."ipv6.ignore-auto-dns" = true;

    # 本机启动后无强依赖网络的服务（SSH/代理均在用户登录后拉起），
    # 等待全部接口上线纯属浪费时间，禁用以省下约 4.7s 启动耗时
    systemd.services.NetworkManager-wait-online.enable = false;
  };
}
