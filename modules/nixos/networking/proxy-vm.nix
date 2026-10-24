# 把主机 HTTP 代理转发给 libvirt NAT 网段里的客户机（Windows VM 上网用）
#
# mihomo（Clash Verge）默认只监听 127.0.0.1（allow-lan: false），而 libvirt 默认
# NAT 网络的网关就是宿主机（192.168.122.1）：客户机把系统代理指到该地址会直接
# 被拒（Connection refused），因为宿主在这个地址上没有监听者。
#
# 两条常见出路都不可取：
#   - 在 Clash Verge 里开「允许局域网连接」：mihomo 改绑 0.0.0.0，代理顺带对整个
#     局域网开放；而且该开关是 GUI 状态（不归 Nix 管），重建/重装后不保证还在；
#   - 仿 Docker 用 nftables DNAT 到 127.0.0.1：需要打开
#     net.ipv4.conf.all.route_localnet，等于允许把回环地址当可路由地址使用，
#     并且对**所有**接口生效，收窄了内核的默认安全假设。
#
# 故改为在网桥地址上做一次显式 TCP 转发：监听范围仅限 virbr0（客户机网段），
# 不触碰全局 sysctl，也不依赖 Clash 侧的 GUI 开关。
# 客户机侧仍需一次性把系统代理指向 http://192.168.122.1:<port>（见 docs/winapps.md §10.4）。
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
in
{
  options.mySystem.proxy.exposeToVms = lib.mkEnableOption "把主机代理转发到 libvirt 网桥（供客户机上网）";

  config = {
    # 误用防护：exposeToVms 开而 virtualization 未开时，virbr0 永不出现，
    # 下面的转发服务只能靠 Restart 轮询无限空转（注释自己承认的场景，
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
  };
}
