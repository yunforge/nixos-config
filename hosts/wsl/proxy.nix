# WSL2 代理地址自适应
#
# Windows 侧 FlClash 监听 mySystem.proxy.port，但 WSL2 的网络模式由
# Windows 侧 %USERPROFILE%\.wslconfig 决定，不在本仓库管理范围内：
#   - mirrored 模式：Windows 的 localhost 映射进容器，127.0.0.1 直接可达
#   - NAT 模式（默认）：Windows 宿主位于容器默认网关，127.0.0.1 不可达
# 两种模式下代理地址不同，无法写死。故在启动时探测可达的那一个写入 envFile。
#
# proxy 模块静态注入的 127.0.0.1 退化为 mirrored 模式的默认值：
# EnvironmentFile 的条目优先级高于 Environment=，NAT 模式下被探测结果覆盖。
# 代理地址不可达时 http_proxy 语义是“只用代理且直接失败”，nix 不会回退直连，
# 只能转源码构建——autoUpgrade 每日滚 flake.lock 会因此触发巨量本地编译，
# 所以 nix-daemon 与 nixos-upgrade 必须拿到正确地址。
{
  lib,
  config,
  pkgs,
  ...
}:
let
  cfg = config.mySystem.proxy;
  envFile = "/run/clash-proxy/env";

  # 探测代理地址并写出 systemd EnvironmentFile（KEY=value 格式）
  probeScript = pkgs.writeShellScript "clash-proxy-env" ''
    port=${toString cfg.port}
    host=127.0.0.1

    # bash 的 /dev/tcp 不依赖外部命令；必须经 timeout 包一层 bash -c，
    # 否则重定向由当前 shell 打开，连接挂起时 timeout 尚未 exec，超时失效
    probe() {
      timeout 1 bash -c "exec 3<>/dev/tcp/$1/$port" 2>/dev/null
    }

    if ! probe "$host"; then
      gw=$(ip route show default 2>/dev/null | awk '/^default/ {print $3; exit}')
      if [ -n "$gw" ] && probe "$gw"; then
        host="$gw"
      fi
    fi

    install -D -m 644 /dev/stdin "${envFile}" <<EOF
    http_proxy=http://$host:$port
    https_proxy=http://$host:$port
    ftp_proxy=http://$host:$port
    no_proxy=${config.environment.sessionVariables.no_proxy}
    EOF
  '';
in
{
  config = lib.mkIf cfg.enable {
    systemd.services.clash-proxy-env = {
      description = "探测 WSL2 宿主代理地址（127.0.0.1 或默认网关）";
      wantedBy = [ "multi-user.target" ];
      path = [
        pkgs.coreutils
        pkgs.iproute2
        pkgs.gawk
      ];
      serviceConfig = {
        Type = "oneshot";
        RemainAfterExit = true;
      };
      script = "exec ${probeScript}";
    };

    systemd.services.nix-daemon = {
      after = [ "clash-proxy-env.service" ];
      # 前缀 "-" 容忍文件缺失（探测服务失败时退回 Environment= 的静态值，
      # 而不是让 nix-daemon 起不来）
      serviceConfig.EnvironmentFile = "-" + envFile;
    };

    # autoUpgrade 的 --refresh 由该服务以 root 身份执行，拉取 flake 输入
    # 走的是客户端进程而非守护进程，需要单独注入代理环境
    systemd.services.nixos-upgrade = {
      after = [ "clash-proxy-env.service" ];
      serviceConfig.EnvironmentFile = "-" + envFile;
    };

    # 交互式 shell：覆盖 sessionVariables 里的静态 127.0.0.1。
    # 非交互的 root 会话（如 sudo）仍拿到静态值，NAT 模式下会直连失败而报错，
    # 失败是显式的，不会静默退回源码构建。
    home-manager.users.${config.mySystem.primaryUser}.programs.fish.shellInit = ''
      if test -f ${envFile}
        while read -l line
          set -l kv (string split -m1 '=' -- $line)
          if test (count $kv) -eq 2
            set -gx $kv[1] $kv[2]
          end
        end < ${envFile}
      end
    '';
  };
}
