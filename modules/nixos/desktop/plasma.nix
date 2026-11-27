# KDE Plasma 6 桌面环境 — 系统级配置
#
# 与 niri 并存：二者各自注册一个登录会话，在 SDDM 的会话菜单里可切换。
# 选项就近定义在实现模块（与 niri/default.nix 同构）；某台主机是否启用
# 由 hosts/ 写例外，能力聚合模块不给默认值。
{
  lib,
  config,
  pkgs,
  ...
}:
let
  cfg = config.mySystem.desktop.plasma;
  desktopCfg = config.mySystem.desktop;

  # KDE 会话用的 XDG autostart 替换 Exec（见下方 config 里的说明）：
  # KDE 下让路给 KWin 启动输入法，其它会话（niri）照旧 exec fcitx5，
  # 保留 systemd 单元托管与 restart/journal 工作流。
  fcitxAutostart = pkgs.writeShellScriptBin "fcitx5-autostart" ''
    if [ "''${XDG_CURRENT_DESKTOP:-}" = "KDE" ] || [ "''${XDG_SESSION_DESKTOP:-}" = "plasma" ]; then
      exit 0
    fi
    exec ${config.i18n.inputMethod.package}/bin/fcitx5
  '';
in
{
  options.mySystem.desktop.plasma.enable = lib.mkEnableOption "KDE Plasma 6 桌面环境";

  config = lib.mkIf (cfg.enable && desktopCfg.enable) {
    # 安装 Plasma 6（Wayland 会话）。它会把 plasma-workspace 的会话加入
    # services.displayManager.sessionPackages，与 niri 的会话合并注册到 SDDM。
    services.desktopManager.plasma6.enable = true;

    # KWin 6.8.3 注销/登录黑屏回归（KDE #528824）的上游修复回移。
    # 6.8.3 把 libinput 初始事件队列放在 InputRedirection 构造函数里处理，此时
    # 全局单例尚未设置；注销/登录瞬间的 pointer motion 会解引用空指针，使 SDDM 的
    # Wayland greeter kwin 崩溃、greeter 随之退出，而 SDDM 不重启 greeter → 黑屏。
    # 修复（6.8.4）把 setupInputBackends() 从构造函数移到 init()，共 2 行；
    # 补丁取自上游 6.8 分支 cherry-pick 19404161bc367b87b794361915b85a14c034ec63。
    # 只在本模块生效（Plasma 主机），不进 overlays/default.nix：后者同时供
    # flake 的 packages 输出枚举，把 kdePackages 整体覆盖会污染那批输出。
    # 移除条件：nixpkgs 的 kwin 升到 >= 6.8.4 后，删除本 overlay 与
    # pkgs/kwin/input-init-after-redirection.patch，并删 docs/quirks.md 对应条目。
    nixpkgs.overlays = [
      (final: prev: {
        kdePackages = prev.kdePackages.overrideScope (
          kfinal: kprev: {
            kwin = kprev.kwin.overrideAttrs (old: {
              # 6.8.4 起上游已含修复；版本守卫让 nixpkgs 滚动到 6.8.4 后
              # 补丁自动失效，不会因上下文不匹配让每周 autoUpgrade 构建失败。
              patches =
                (old.patches or [ ])
                ++ lib.optionals (lib.versionOlder old.version "6.8.4") [
                  ../../../pkgs/kwin/input-init-after-redirection.patch
                ];
            });
          }
        );
      })
    ];

    # KDE 默认会装一大堆自家应用。本仓库已有等价工具，这里按包名排除重复/用不到的，
    # 只保留 Plasma 桌面本体与必要的集成组件（机制：plasma6 模块把这些放在
    # optionalPackages，用 environment.plasma6.excludePackages 按包名剔除）。
    environment.plasma6.excludePackages = with pkgs.kdePackages; [
      baloo-widgets
      gwenview # 图片查看 → qView
      okular # 文档/PDF → Papers
      elisa # 音乐播放（仓库不装独立播放器）
      ark # 压缩包管理 → File Roller
      ffmpegthumbs # 视频缩略图（Dolphin 的缩略图能力一并排除）
      khelpcenter # 帮助中心
      krdp # 远程桌面服务端
      qrca # 二维码扫描
      discover # 软件中心（用 Nix，不需要；仅在 flatpak/fwupd 时才会装）
      plasma-workspace-wallpapers # 额外壁纸
      union # 实验性全局主题
    ];

    # plasma6 模块以 `mkDefault true` 打开 programs.kde-pim，会装进 KDE PIM 全家桶：
    # 基础层 akonadi / akonadi-import-wizard / kdepim-runtime，加上默认继承的子开关
    # KMail（kmail / kmail-account-wizard / akonadiconsole / akonadi-search）、
    # Kontact，以及 Merkuro（merkuro / kcontacts / akonadi-contacts）。本机不用
    # 邮件、日历、通讯录这套，整体关闭；上游安装镜像也以普通赋值 false 覆盖该默认值。
    programs.kde-pim.enable = false;

    # 登录默认进入 Plasma。注意冲突点：plasma6 模块自身以 `mkDefault "plasma"`
    # 声明本项，而 niri 模块以 `mkDefault "niri"` 声明，两个同优先级（1000）的
    # mkDefault 取值不同会直接报 conflicting definition values。这里改用普通赋值
    # （优先级 100）明确选 plasma，既压过两个 mkDefault，又只在启用 plasma 的主机
    # 上生效（纯 niri 主机不受影响，仍是 niri 默认）。
    services.displayManager.defaultSession = "plasma";

    # 输入法（fcitx5）在 KDE Wayland 下必须由 KWin 亲自拉起：KWin 只在 startSession
    # 时按 kwinrc `[Wayland] InputMethod`（本机已指向 org.fcitx.Fcitx5.desktop）用
    # QProcess 启动配置的命令，并给它一条专用 Wayland 连接（WAYLAND_SOCKET）；只有承担
    # input-method-v2 角色的那条连接，text-input 上下文才会被送到 fcitx。若让 XDG
    # autostart 的 systemd 单元先拉起一个普通 fcitx 实例，KWin 拿不到该角色，应用就只剩
    # 英文（实测 fcitx 端 `Group [wayland:] has 0 InputContext(s)` 而 KWin `.active=true`）。
    # 故 KDE 会话让 autostart 空转，交由 KWin 启动；niri 仍由 systemd 单元托管
    # （`systemctl --user restart app-org.fcitx.Fcitx5@autostart.service` 与 journal 不变）。
    # 覆盖包自带的 /run/current-system/sw/etc/xdg/autostart/…：XDG_CONFIG_DIRS 中
    # /etc/xdg 先于 /run/current-system/sw/etc/xdg，故本文件胜出。
    environment.etc."xdg/autostart/org.fcitx.Fcitx5.desktop".text = ''
      [Desktop Entry]
      Type=Application
      Name=Fcitx 5
      GenericName=Input Method
      Comment=Start Input Method
      Exec=${fcitxAutostart}/bin/fcitx5-autostart
      Icon=fcitx
      NoDisplay=true
      Terminal=false
      Categories=System;Utility;
      StartupNotify=false
      X-GNOME-AutoRestart=false
      X-GNOME-Autostart-Notify=false
      X-KDE-autostart-after=panel
      X-KDE-StartupNotify=false
    '';

    # KWin 的 NVIDIA workaround。KDE 桌面的光标主题/尺寸不在这里设置：
    # XCURSOR_* 已不再由 NixOS 全局注入（见 modules/nixos/desktop/env.nix），
    # KWin 回落到 kcminputrc；该文件由 HM 的 kde-appearance.nix 在激活时写入
    # （Bibata-Modern-Ice / 24），其余键仍由 Plasma 运行时维护。
    #
    # `KWIN_DRM_NO_DIRECT_SCANOUT=1`：KWin 6.8 在 NVIDIA 上反复尝试 direct scanout，
    # 交换链缓冲区分配失败时会在「直扫」与「合成」两条管线之间来回切换，表现为外接屏
    # 亮度/伽马快速闪烁，日志同步刷 `Failed to allocate a graphics buffer for a
    # swapchain`（KDE bug 527184；本机 6.8.2 + 595.112.07 仍复现）。关掉直扫强制走
    # 合成管线可同时消除闪烁与报错，代价是少一条省电路径。
    #
    # 注意：`environment` 选项默认会顺带注入 NixOS 的最小 PATH
    # （`enableDefaultPath` 把 `systemd.defaultPath` 追加进单元的 PATH），而 KWin 单元
    # 本是包提供的，靠继承会话 PATH 找到 `/run/current-system/sw/bin/Xwayland`。一旦
    # drop-in 用最小 PATH 覆盖掉它，KWin 找不到 Xwayland 会静默挂起 —— 表现就是进 KDE
    # 后黑屏（实测：minimal PATH 下 `kwin_wayland_wrapper --virtual` 无输出、rc=124；
    # 加上 `:/run/current-system/sw/bin` 即正常启动）。故关掉默认 PATH，让单元继续继承
    # 会话 PATH；drop-in 里只保留 KWin 自己的变量。
    systemd.user.services."plasma-kwin_wayland" = {
      overrideStrategy = "asDropin";
      enableDefaultPath = false;
      environment = {
        KWIN_DRM_NO_DIRECT_SCANOUT = "1";
      };
    };

    # Plasma 6.8 注销竞态（KDE bug 527660）：plasma-shutdown 的 logoutComplete()
    # 用 `plasma-workspace.target` 是否仍 active 判断是不是 systemd 会话；实测该
    # target 此时已经停止，于是走了旧分支，没有执行 StopUnit graphical-session.target，
    # 旧 graphical target 残留 active。下一次登录时，XDG autostart 单元只写
    # `After=graphical-session.target`，该条件立即满足，plasma-fallback-session-restore
    # 等应用会在 KWin 建出 Wayland socket 前启动，Qt 初始化 wayland 插件失败并 SIGABRT。
    #
    # 让 graphical target 随 workspace target 一起停：下一次登录时 autostart 必须等
    # graphical target 重新到达，而它会等 plasma-workspace.target → plasma-core.target
    # （后者 After=plasma-kwin_wayland.service），因此不会再抢跑。
    # 上游给的 `startkderc` `systemdBoot=false` workaround 会关掉 systemd 会话管理，不采用。
    systemd.user.targets."graphical-session" = {
      overrideStrategy = "asDropin";
      partOf = [ "plasma-workspace.target" ];
    };
  };
}
