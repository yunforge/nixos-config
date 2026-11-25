# 代理配置模块
# 需要代理的主机通过 mySystem.proxy.enable = true 开启
{ lib, config, ... }:
let
  cfg = config.mySystem.proxy;
  proxyUrl = "http://127.0.0.1:${toString cfg.port}";
  # 直连白名单。curl/libcurl（Nix 下载器）的 no_proxy 语义：
  # - 域名按后缀匹配（写 "ts.net" 即匹配所有 <tailnet>.ts.net），不支持
  #   "*.ts.net" 这类通配；
  # - IPv6 直接写地址，不要加方括号；CIDR 需 libcurl >= 7.86（NixOS 满足）。
  # 国内镜像直连更快（实测经代理约慢 9 倍）；cache.nixos.org 反而经代理更快，
  # 故不列入。
  noProxyList = lib.concatStringsSep "," [
    "localhost"
    "127.0.0.1"
    "::1"
    "local.domain"
    # 局域网 / 容器 / 虚拟机 / 链路本地
    "192.168.0.0/16"
    "10.0.0.0/8"
    "172.16.0.0/12"
    "169.254.0.0/16"
    # Tailscale tailnet：CGNAT IPv4、ULA IPv6、MagicDNS HTTPS 域名
    "100.64.0.0/10"
    "fd7a:115c:a1e0::/48"
    "ts.net"
    # 国内 Nix 镜像：直连快于代理
    "mirrors.tuna.tsinghua.edu.cn"
    "mirrors.ustc.edu.cn"
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
