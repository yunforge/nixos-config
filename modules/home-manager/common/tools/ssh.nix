# SSH 客户端 — GitHub 走本地代理
#
# git 的 HTTPS 传输会读取 http_proxy/https_proxy，SSH 不读，只会直连 22 端口；
# 直连 GitHub 的 22 端口在部分网络下被 QoS 限速。这里用 ProxyCommand 让 SSH
# 复用 mihomo 的 mixed 端口，与 HTTPS 走同一条线路。
#
# 只在开启 mySystem.proxy 且代理地址稳定的主机生成。WSL 的代理地址要按模式
# 运行时探测（mirrored 为 127.0.0.1，NAT 为默认网关，见 hosts/wsl/proxy.nix），
# 静态 ProxyCommand 适配不了，故整个 WSL 跳过。
{
  lib,
  config,
  osConfig,
  pkgs,
  ...
}:
let
  cfg = config.myHome.cli.tools.ssh;
  cliCfg = config.myHome.cli;
  sysProxy =
    if osConfig ? mySystem && osConfig.mySystem ? proxy then osConfig.mySystem.proxy else null;
  isWsl = osConfig ? wsl && osConfig.wsl.enable;
  proxyEnabled = sysProxy != null && (sysProxy.enable or false) && !isWsl;
in
{
  options.myHome.cli.tools.ssh.enable = lib.mkOption {
    type = lib.types.bool;
    default = true;
    description = "启用 SSH 客户端配置（GitHub 经本地代理）";
  };

  config = lib.mkIf (cfg.enable && cliCfg.enable && proxyEnabled) {
    programs.ssh = {
      enable = true;
      # 不生成 HM 的 Host * 默认块，只写需要的条目。
      enableDefaultConfig = false;
      settings."github.com" = {
        HostName = "github.com";
        User = "git";
        # 用 libressl 的 nc（OpenBSD 版，支持 -X connect），不依赖登录 shell 的 PATH。
        ProxyCommand = "${pkgs.libressl.nc}/bin/nc -X connect -x 127.0.0.1:${toString sysProxy.port} %h %p";
      };
    };
  };
}
