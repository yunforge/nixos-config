# 代理配置模块
# 需要代理的主机通过 mySystem.proxy.enable = true 开启
{ lib, config, ... }:
let
  cfg = config.mySystem.proxy;
  proxyUrl = "http://127.0.0.1:${toString cfg.port}";
  noProxyList = lib.concatStringsSep "," [
    "localhost"
    "127.0.0.1"
    "local.domain"
    "192.168.0.0/16"
  ];
  proxyEnv = {
    http_proxy = proxyUrl;
    https_proxy = proxyUrl;
    ftp_proxy = proxyUrl;
    no_proxy = noProxyList;
  };
in
{
  options.mySystem.proxy = {
    enable = lib.mkEnableOption "HTTP/HTTPS 代理";
    port = lib.mkOption {
      type = lib.types.int;
      default = 7897;
      description = "代理端口（本机 FlClash 默认 7897）";
    };
    dnsPort = lib.mkOption {
      type = lib.types.int;
      default = 1053;
      description = "mihomo DNS 端口（FlClash 默认 1053，供客户机 DNS 劫持使用）";
    };
  };

  config = lib.mkIf cfg.enable {
    systemd.services.nix-daemon.environment = proxyEnv;
    environment.sessionVariables = proxyEnv;
  };
}
