# KDE Plasma 6 桌面环境 — 系统级配置
#
# 与 niri 并存：二者各自注册一个登录会话，在 GDM 的会话菜单里可切换。
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
    # services.displayManager.sessionPackages，与 niri 的会话合并注册到 GDM。
    services.desktopManager.plasma6.enable = true;

    # KDE 默认会装一大堆自家应用。本仓库已有等价工具，这里按包名排除重复/用不到的，
    # 只保留 Plasma 桌面本体与必要的集成组件（机制：plasma6 模块把这些放在
    # optionalPackages，用 environment.plasma6.excludePackages 按包名剔除）。
    environment.plasma6.excludePackages = with pkgs.kdePackages; [
      konsole # 终端 → Ghostty
      baloo-widgets
      gwenview # 图片查看 → qView
      okular # 文档/PDF → Papers
      elisa # 音乐播放 → Gapless
      ark # 压缩包管理 → File Roller
      ffmpegthumbs # 视频缩略图（配合 Dolphin，已移除）
      khelpcenter # 帮助中心
      krdp # 远程桌面服务端
      qrca # 二维码扫描
      discover # 软件中心（用 Nix，不需要；仅在 flatpak/fwupd 时才会装）
      plasma-workspace-wallpapers # 额外壁纸
      union # 实验性全局主题
    ];

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

    # KDE 下把 KWin 的光标尺寸钉回 24 逻辑像素。仓库全局 `XCURSOR_SIZE=48` 是给
    # niri / xwayland-satellite 的 X11 光标翻倍用的（libXcursor 只认物理像素），
    # 但 KWin 在 `XCURSOR_THEME` 非空时会直接把 `XCURSOR_SIZE` 当作**逻辑**光标尺寸
    # （kwin src/cursor.cpp `loadThemeSettings`：theme 与 size 都在则优先环境变量，
    # 否则回落到 kcminputrc 的 cursorSize，默认 24）。于是 Plasma 的光标变成 48
    # 逻辑像素、明显偏大。这里只覆盖 KWin 单元的该变量为 24，与 niri 的 24 逻辑像素
    # 一致；其它会话仍用全局 48。
    #
    # 注意：`environment` 选项默认会顺带注入 NixOS 的最小 PATH
    # （`enableDefaultPath` 把 `systemd.defaultPath` 追加进单元的 PATH），而 KWin 单元
    # 本是包提供的，靠继承会话 PATH 找到 `/run/current-system/sw/bin/Xwayland`。一旦
    # drop-in 用最小 PATH 覆盖掉它，KWin 找不到 Xwayland 会静默挂起 —— 表现就是进 KDE
    # 后黑屏（实测：minimal PATH 下 `kwin_wayland_wrapper --virtual` 无输出、rc=124；
    # 加上 `:/run/current-system/sw/bin` 即正常启动）。故关掉默认 PATH，让单元继续继承
    # 会话 PATH；drop-in 里只保留 XCURSOR_SIZE。
    systemd.user.services."plasma-kwin_wayland" = {
      overrideStrategy = "asDropin";
      enableDefaultPath = false;
      environment.XCURSOR_SIZE = "24";
    };
  };
}
