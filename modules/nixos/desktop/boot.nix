# 启动日志配置 — 安静模式
{
  lib,
  config,
  pkgs,
  ...
}:
let
  cfg = config.mySystem.desktop;
in
{
  config = lib.mkIf cfg.enable {
    boot = {
      consoleLogLevel = 3;
      kernelParams = [
        "fbcon=nodefer"
        "nvidia_drm.fbdev=1"
        "console=tty1"
      ];

      # 硬冻结（桌面无响应、只能按电源键）现场捕获 + 软恢复。
      # 根因疑为 NVIDIA 专有驱动挂死，但默认 hung_task_panic=0、panic_on_oops=0
      # 导致卡死时内核只警告不抓 trace，日志又因硬断电损坏 → 无从诊断。
      # 全部值已在本机内核确认存在。
      kernel.sysctl = {
        # sysrq=1（当前仅 16）：卡死时可用 Alt+SysRq+REISUB 软重启，避免硬断电损坏 BTRFS/journal
        "kernel.sysrq" = 1;
        "kernel.hung_task_timeout_secs" = 60;
        # 任务挂起时打印全 CPU 栈并 panic，panic 后 30s 自动重启
        "kernel.hung_task_panic" = 1;
        "kernel.hung_task_all_cpu_backtrace" = 1;
        "kernel.softlockup_all_cpu_backtrace" = 1;
        "kernel.panic" = 30;
      };
    };

    # TTY 控制台字体 — Terminus 32px 粗体，适配高分屏
    # console.packages 确保字体在 initrd 早期阶段可用
    console = {
      font = "ter-i32b";
      packages = [ pkgs.terminus_font ];
      earlySetup = true;
    };
  };
}
