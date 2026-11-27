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

  config = lib.mkIf cfg.network.enable {
    # iwd 是 NetworkManager 的 WiFi 后端，包随服务走（曾在 core 给所有主机
    # 装二进制，包括不开网络能力的 server/wsl）
    environment.systemPackages = [ pkgs.iwd ];
    networking.wireless.iwd.enable = true;
    # 启用 NetworkManager
    networking.networkmanager.enable = true;
    networking.networkmanager.wifi.backend = "iwd";

    # NM 的 [connection] 默认值不支持 ignore-auto-dns（启动日志 unknown key，纯 no-op），
    # 压不掉路由器 RA 下发的 v6 DNS；修法在路由器上游 DNS 或单连接配置，见 docs/quirks.md。

    # 本机无强依赖网络的服务（sshd 开机即起但绑 0.0.0.0、无需等接口上线；
    # 代理才在用户登录后拉起），等待全部接口上线纯属浪费时间，禁用以省下约 4.7s 启动耗时
    systemd.services.NetworkManager-wait-online.enable = false;
  };
}
