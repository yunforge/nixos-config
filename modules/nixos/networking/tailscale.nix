# Tailscale 组网模块
#
# 能力域：networking。普通客户端模式 —— 只加入 tailnet 互相访问，
# 不做子网路由器或出口节点（无需 IP 转发，不动防火墙 reverse path 策略）。
#
# 认证：不落盘 authKeyFile（上游密钥最长 90 天，轮换不如手动登录省事）。
# 首次使用在每台主机上执行一次：
#   sudo tailscale up
# 登录后状态由 /var/lib/tailscale 持久化，重装/升级无需重新认证。
{
  lib,
  config,
  ...
}:
let
  cfg = config.mySystem.tailscale;
in
{
  options.mySystem.tailscale = {
    enable = lib.mkEnableOption "Tailscale 组网（普通客户端）";
  };

  config = lib.mkIf cfg.enable {
    services.tailscale = {
      # 在启动时启用 tailscale
      enable = true;
      # 普通客户端：不启用子网路由 / 出口节点相关内核与防火墙设置
      useRoutingFeatures = "none";
    };

    # 信任 Tailscale 接口：tailnet 内设备互相访问不再被防火墙拦截。
    # 接口名由 services.tailscale.interfaceName 决定（默认 "tailscale0"），
    # 引用而非硬编码，上游改名时跟随。
    networking.firewall.trustedInterfaces = [ config.services.tailscale.interfaceName ];
  };
}
