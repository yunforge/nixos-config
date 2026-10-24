# 每日 AI 签到 — 用无头浏览器自动完成多站点每日签到
#
# 不是常驻服务：systemd user timer 每天 09:07 拉起一次，跑完即退出。
# 数据目录 ~/checkin 不由本模块管理（脚本、登录 profile、日志都在那里，
# 需要每天写，不能进 nix store），本模块只负责「定时拉起」这层。
#
# 手动触发：systemctl --user start daily-checkin.service
# 看结果：~/checkin/logs/<日期>.md；需要人工时会写 ~/checkin/NEEDS_HUMAN.md
# 并弹桌面通知。
#
# 运行环境有个 NixOS 特有的坑：Playwright 自带的 chromium 缺一串共享库，
# 直接起会报 libglib 找不到。脚本自己从 ~/checkin 读 LD_LIBRARY_PATH
# （由 ~/checkin/ld-lib-path-1248.txt 提供），这里不再重复维护。
{
  lib,
  config,
  pkgs,
  ...
}:
let
  cfg = config.myHome.cli.tools.daily-checkin;
  cliCfg = config.myHome.cli;
in
{
  options.myHome.cli.tools.daily-checkin = {
    enable = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = ''
        启用每日 AI 签到：systemd user timer 每天 09:07 运行 ~/Projects/checkin/run.sh，
        用无头浏览器对已配置的站点执行签到。脚本与登录态存放在 ~/checkin
        （不由本模块管理），本模块只提供定时与手动启动入口。
      '';
    };

    calendar = lib.mkOption {
      type = lib.types.str;
      default = "*-*-* 09:07:00";
      description = "systemd OnCalendar 表达式，默认每天 09:07。";
    };
  };

  config = lib.mkIf (cfg.enable && cliCfg.enable && pkgs.stdenv.hostPlatform.isLinux) {
    systemd.user.services.daily-checkin = {
      Unit = {
        Description = "每日 AI 签到（多站点无头浏览器）";
        # 桌面会话在跑才弹通知；没有也在后台照跑
        After = [ "graphical-session.target" ];
      };
      Service = {
        Type = "oneshot";
        # 不用 run.sh 的 shebang，显式指 bash：Exec* 是直接 execve，NixOS 无 /usr/bin
        ExecStart = "${pkgs.bash}/bin/bash ${config.home.homeDirectory}/Projects/checkin/run.sh";
        # 单站最多 5 分钟，两个站加上浏览器启停，10 分钟足够；超时即判失败
        TimeoutStartSec = "10m";
        StandardOutput = "journal";
        StandardError = "journal";
      };
    };

    systemd.user.timers.daily-checkin = {
      Unit = {
        Description = "每日 AI 签到定时器";
      };
      Timer = {
        OnCalendar = cfg.calendar;
        Persistent = true; # 关机错过的话，开机后补跑当天一次
        Unit = "daily-checkin.service";
      };
      Install = {
        WantedBy = [ "timers.target" ];
      };
    };
  };
}
