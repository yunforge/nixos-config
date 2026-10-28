# 把主机 HTTP 代理转发给 libvirt NAT 网段里的客户机
#
# mihomo（Clash Verge）默认只监听 127.0.0.1（allow-lan: false），而 libvirt 默认
# NAT 网络的网关就是宿主机（192.168.122.1）。本模块提供两种互不冲突的方式：
#
#   - exposeToVms：在网桥地址上 socat 转发到回环端口，客户机手动把系统代理
#     指向 192.168.122.1:<port>（Windows 见 docs/winapps.md §10.4）；
#   - transparentForVms：在 virbr0 上做 iptables 重定向 + redsocks，客户机
#     零配置，所有 TCP 自动经 mihomo；DNS 劫持到 mihomo 的 fake-ip DNS，
#     UDP/QUIC 丢弃迫使应用回落 TCP。
#
# 两条常见出路都不可取：
#   - 在 Clash Verge 里开「允许局域网连接」：mihomo 改绑 0.0.0.0，代理顺带对整个
#     局域网开放；而且该开关是 GUI 状态（不归 Nix 管），重建/重装后不保证还在；
#   - 仿 Docker 用 nftables DNAT 到 127.0.0.1：需要打开
#     net.ipv4.conf.all.route_localnet，等于允许把回环地址当可路由地址使用，
#     并且对**所有**接口生效，收窄了内核的默认安全假设。
#
# 故 exposeToVms 在网桥地址上做一次显式 TCP 转发（监听范围仅限 virbr0，不触碰
# 全局 sysctl）；transparentForVms 用 REDIRECT 把目的地址改写成 virbr0 的地址，
# redsocks 只监听该地址，同样不需要 route_localnet，也不依赖 Clash 侧的 GUI 开关。
{
  lib,
  config,
  pkgs,
  ...
}:
let
  cfg = config.mySystem.proxy;

  # libvirt 默认网络（network 'default'，autostart = yes）的网桥。本仓库未自定义
  # libvirt 网络，故沿用默认名；若日后改了网络定义，此处需同步。
  bridge = "virbr0";

  # 重试间隔：virbr0 未就绪时按此周期重启（libvirtd 为 socket 激活，网桥随
  # libvirtd/默认网络启动才出现，开机瞬间未必存在）
  retrySec = 10;

  # redsocks 在网桥地址上的监听端口（仅客户机可达，与 mihomo 的 7897 分开）
  redsocksPort = 12345;
in
{
  options.mySystem.proxy.exposeToVms = lib.mkEnableOption "把主机代理转发到 libvirt 网桥（供客户机手动配置代理）";

  options.mySystem.proxy.transparentForVms = lib.mkEnableOption "把 libvirt 客户机的 TCP 与 DNS 透明转发到主机代理（客户机零配置）";

  config = {
    # 误用防护：exposeToVms / transparentForVms 开而 virtualization 未开时，
    # virbr0 永不出现，转发服务只能靠 Restart 轮询无限空转（注释自己承认的场景，
    # 升级为 assertion 在构建期拦下）
    assertions = [
      {
        assertion = cfg.exposeToVms -> config.mySystem.virtualization.enable;
        message = ''
          mySystem.proxy.exposeToVms 已开启，但 mySystem.virtualization.enable 未开启：
          libvirt 默认网桥 virbr0 不会存在，libvirt-proxy-forward 只能无限重试。
          先开虚拟化，或关掉 exposeToVms。
        '';
      }
      {
        assertion = cfg.transparentForVms -> config.mySystem.virtualization.enable;
        message = ''
          mySystem.proxy.transparentForVms 已开启，但 mySystem.virtualization.enable 未开启：
          libvirt 默认网桥 virbr0 不会存在，透明代理规则永远不会命中。
          先开虚拟化，或关掉 transparentForVms。
        '';
      }
      {
        assertion = cfg.transparentForVms -> cfg.enable;
        message = ''
          mySystem.proxy.transparentForVms 已开启，但 mySystem.proxy.enable 未开启：
          没有可用的上游代理端口。先开代理，或关掉 transparentForVms。
        '';
      }
    ];

    systemd.services.libvirt-proxy-forward = lib.mkIf (cfg.enable && cfg.exposeToVms) {
      description = "把主机代理（Clash Verge）转发到 libvirt 网桥";

      # 不声明 libvirtd 依赖：libvirtd 是 socket 激活的，virbr0 何时出现不由本单元
      # 掌控，靠 Restart 轮询等待更可靠（每次重试都在日志里写明原因）。
      wantedBy = [ "multi-user.target" ];
      after = [ "network.target" ];
      # 网桥长期未出现（未装 libvirt 的主机误开此项）时要能一直等下去，
      # 不能被 systemd 的启动频率限制（默认 10s 内 5 次）卡在 failed
      unitConfig.StartLimitIntervalSec = 0;

      serviceConfig = {
        Type = "simple";
        Restart = "always";
        RestartSec = retrySec;
      };

      path = [
        pkgs.iproute2
        pkgs.gawk
        pkgs.coreutils
      ];

      script = ''
        port=${toString cfg.port}
        bridge=${bridge}
        target=127.0.0.1

        # 解析网桥当前的 IPv4 地址（即客户机看到的网关），不写死 192.168.122.1：
        # 网段由 libvirt 网络定义决定，改了定义这里应跟着走
        addr=$(ip -4 -o addr show dev "$bridge" 2>/dev/null | awk '{ split($4, a, "/"); print a[1]; exit }')
        if [ -z "$addr" ]; then
          echo "$(date '+%F %T') libvirt-proxy-forward: 网桥 $bridge 无 IPv4 地址（libvirt 默认网络未就绪），${toString retrySec}s 后重试" >&2
          exit 1
        fi

        echo "$(date '+%F %T') libvirt-proxy-forward: $bridge $addr:$port -> $target:$port（监听仅限本网桥）"
        # fork：每个客户机连接一个子进程；TCP 直通，HTTP CONNECT 等语义由客户机与代理自行协商
        exec ${pkgs.socat}/bin/socat "TCP-LISTEN:$port,bind=$addr,fork,reuseaddr" "TCP:$target:$port"
      '';
    };

    # 透明模式的后端：redsocks 接收被 REDIRECT 进来的客户机 TCP，再用 HTTP
    # CONNECT 转给 mihomo 的 mixed 端口。只监听网桥地址，不暴露给局域网。
    services.redsocks = lib.mkIf (cfg.enable && cfg.transparentForVms) {
      enable = true;
      redsocks = [
        {
          ip = "192.168.122.1";
          port = redsocksPort;
          proxy = "127.0.0.1:${toString cfg.port}";
          type = "http-connect";
          # 不启用模块自带的 iptables 规则：那些规则挂在 OUTPUT 上，会连宿主
          # 自己的流量一起劫持；virbr0 的 PREROUTING 规则由本模块显式管理
          redirectCondition = false;
        }
      ];
    };

    systemd.services.redsocks = lib.mkIf (cfg.enable && cfg.transparentForVms) {
      # redsocks 绑定 virbr0 的地址；libvirtd 是 socket 激活的，开机时该地址
      # 可能尚未出现，绑定失败后必须继续重试（NixOS 模块默认没有 Restart）
      unitConfig.StartLimitIntervalSec = 0;
      serviceConfig = {
        Restart = "always";
        RestartSec = retrySec;
      };
    };

    # 透明转发规则只在防火墙脚本里维护，不引入 nftables 后端切换。
    # REDIRECT 在 PREROUTING 中把目的地址改写成入接口（virbr0）的地址，
    # 因此 redsocks 监听 192.168.122.1 即可，无需 route_localnet。
    networking.firewall.extraCommands = lib.mkIf (cfg.enable && cfg.transparentForVms) ''
      # 客户机 -> 外网的 TCP 与 DNS 改投宿主代理；只匹配从 virbr0 进入的
      # 转发流量，不影响宿主自身与局域网。
      iptables -w -t nat -N LIBVIRT_PROXY 2>/dev/null || true
      iptables -w -t nat -F LIBVIRT_PROXY

      # DNS 放在私网放行之前：客户机的默认 DNS 就是网桥地址，也必须改投
      # mihomo 的 fake-ip DNS，否则 mihomo 只能看到 IP、拿不到域名。
      iptables -w -t nat -A LIBVIRT_PROXY -p udp --dport 53 -j REDIRECT --to-ports ${toString cfg.dnsPort}
      iptables -w -t nat -A LIBVIRT_PROXY -p tcp --dport 53 -j REDIRECT --to-ports ${toString cfg.dnsPort}

      # 私网/保留地址直连：含宿主服务、其他 VM、exposeToVms 的 socat 转发口。
      # 注意不要排除 198.18.0.0/16 —— 那是 mihomo fake-ip 的地址段，必须
      # 送进 redsocks 才能映射回域名。
      iptables -w -t nat -A LIBVIRT_PROXY -d 0.0.0.0/8 -j RETURN
      iptables -w -t nat -A LIBVIRT_PROXY -d 10.0.0.0/8 -j RETURN
      iptables -w -t nat -A LIBVIRT_PROXY -d 127.0.0.0/8 -j RETURN
      iptables -w -t nat -A LIBVIRT_PROXY -d 169.254.0.0/16 -j RETURN
      iptables -w -t nat -A LIBVIRT_PROXY -d 172.16.0.0/12 -j RETURN
      iptables -w -t nat -A LIBVIRT_PROXY -d 192.168.0.0/16 -j RETURN
      iptables -w -t nat -A LIBVIRT_PROXY -d 224.0.0.0/4 -j RETURN
      iptables -w -t nat -A LIBVIRT_PROXY -d 240.0.0.0/4 -j RETURN

      # 其余 TCP 全部交给 redsocks（HTTP CONNECT 可承载任意 TCP）
      iptables -w -t nat -A LIBVIRT_PROXY -p tcp -j REDIRECT --to-ports ${toString redsocksPort}

      iptables -w -t nat -D PREROUTING -i ${bridge} -j LIBVIRT_PROXY 2>/dev/null || true
      iptables -w -t nat -A PREROUTING -i ${bridge} -j LIBVIRT_PROXY

      # QUIC 走 UDP，redsocks 无法转发；丢弃 UDP/443 迫使浏览器回落 TCP。
      # 其余 UDP（游戏、语音等）不在本方案的覆盖范围内，仍直连。
      iptables -w -D FORWARD -i ${bridge} -p udp --dport 443 -j DROP 2>/dev/null || true
      iptables -w -I FORWARD 1 -i ${bridge} -p udp --dport 443 -j DROP
    '';

    networking.firewall.extraStopCommands = lib.mkIf (cfg.enable && cfg.transparentForVms) ''
      iptables -w -t nat -D PREROUTING -i ${bridge} -j LIBVIRT_PROXY 2>/dev/null || true
      iptables -w -t nat -F LIBVIRT_PROXY 2>/dev/null || true
      iptables -w -t nat -X LIBVIRT_PROXY 2>/dev/null || true
      iptables -w -D FORWARD -i ${bridge} -p udp --dport 443 -j DROP 2>/dev/null || true
    '';
  };
}
