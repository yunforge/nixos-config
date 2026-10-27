# 桌面环境系统级模块（GDM、环境变量、窗口管理器）
# 仅在 mySystem.desktop.enable = true 时生效
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
  # mySystem.desktop.niri.enable 的选项定义在 ./niri/default.nix（就近原则）

  # 显示器逻辑缩放（Niri 的 fractional scaling 值，如 4K 屏的 1.5）。
  # AWT 的 sun.java2d.uiScale 只接受整数，此处统一声明桌面缩放，
  # 由 env.nix 向上取整后喂给 JVM，避免各处重复推导或硬编码无效值。
  # 默认从下方 monitors 首项派生（单一数据源），主机可显式覆盖。
  options.mySystem.desktop.scale = lib.mkOption {
    type = lib.types.numbers.positive;
    default = 1;
    description = "显示器逻辑缩放（分数缩放值，如 1.5）；AWT 应用会向上取整为整数 uiScale";
  };

  # 显示器声明：主机数据，驱动 niri outputs.kdl 生成、Noctalia 的 DDC 亮度
  # 与状态栏按屏开关（消费方见 modules/home-manager/gui/desktop/linux/niri/）。
  # 共享模块只做生成器，新增/换显示器只动 hosts/。
  options.mySystem.desktop.monitors = lib.mkOption {
    type = lib.types.listOf (
      lib.types.submodule {
        options = {
          name = lib.mkOption {
            type = lib.types.str;
            description = "niri 物理输出名（如 DP-2 / eDP-1）";
          };
          mode = lib.mkOption {
            type = lib.types.nullOr lib.types.str;
            default = null;
            example = "3840x2160@150.000";
            description = "分辨率与刷新率；null 则由 niri 自动选择";
          };
          scale = lib.mkOption {
            type = lib.types.numbers.positive;
            default = 1;
            description = "此输出的逻辑缩放";
          };
          ddc = lib.mkOption {
            type = lib.types.bool;
            default = false;
            description = "此显示器走 DDC/CI 调亮度（需硬件支持且主机已开 hardware.i2c；内屏 eDP 走 sysfs backlight，勿开）";
          };
          bar = lib.mkOption {
            type = lib.types.bool;
            default = true;
            description = "此输出是否显示 Noctalia 状态栏（false = 该屏不生成 bar 实例，Noctalia 默认每块屏都生成一份）";
          };
        };
      }
    );
    default = [ ];
    description = "显示器声明（按主机）：niri 输出配置、Noctalia DDC 亮度与状态栏按屏开关的数据源";
  };

  # 默认壁纸集（产品资产，文件在 assets/wallpapers/）。首项即默认壁纸 —— 与
  # monitors 首项派生 scale 同一约定。
  #
  # 为什么放在系统层：它是**桌面会话与 GDM 登录界面共用的同一张脸**。GDM 侧
  # 要 store 路径（greeter 的 systemd 单元受限、store 世界可读且不可变），
  # Noctalia 侧要部署后的家目录路径（运行时状态会记下这个路径，写 store 路径
  # 会在 rebuild 后失效）。两处同源，故数据只声明一次，HM 经 osConfig 取回。
  #
  # 选图准则（配合 blur.kdl 的 saturation 1.10）：大面积暗部、低彩度、少高频
  # 细节。实测亮度/饱和度与由此重算的透明度依据见 docs/themes.md 的壁纸一节。
  options.mySystem.desktop.wallpapers = lib.mkOption {
    type = lib.types.listOf lib.types.path;
    default = [
      ../../../assets/wallpapers/city-street.jpg
      ../../../assets/wallpapers/ocean-waves.jpg
    ];
    description = "默认壁纸集（首项为默认壁纸），桌面会话与 GDM 登录界面共用";
  };

  imports = [
    ./boot.nix
    ./gdm.nix
    ./env.nix
    ./niri
    ./distrobox.nix
    ./steam.nix
  ];

  config = lib.mkIf cfg.enable {
    # 误用防护：desktop.enable 开而 hardware.enable 关时，Mesa/Vulkan 图形栈
    # （hardware.graphics，仅随 hardware 域启用）不会装上，niri 会静默失去
    # 加速能力。nvidia-base.nix 的 assertion 是同类先例。
    assertions = [
      {
        assertion = config.mySystem.hardware.enable;
        message = ''
          mySystem.desktop.enable 已开启，但 mySystem.hardware.enable 未开启：
          图形栈（hardware.graphics）只随 hardware 域启用，桌面会话将没有
          Mesa/Vulkan 用户态驱动。开启 hardware 域，或确认你了解后果后关闭本检查。
        '';
      }
    ];

    # 逻辑缩放从主显示器（monitors 首项）派生：env.nix 的 AWT/xcursor 推导与
    # niri 的 per-output scale 共用同一数据源，主机不再两处声明（可显式覆盖）
    mySystem.desktop.scale = lib.mkDefault (
      if cfg.monitors == [ ] then 1 else (lib.head cfg.monitors).scale
    );

    # 桌面主机的默认开关集：本仓库两台桌面主机（desktop/laptop）验证过的组合，
    # 主机文件只写例外（与 ../hardware/default.nix 的聚合同构）。关单项用 lib.mkForce。
    mySystem.desktop.niri.enable = lib.mkDefault true;
    mySystem.desktop.distrobox.enable = lib.mkDefault true;
    # 虚拟化与代理的域间联动默认值在角色层（profiles/workstation.nix）声明：
    # libvirtd 是 WinApps/distrobox 的依赖、代理为 mihomo 客户机转发的前置条件，
    # 但这是「工作站才成立」的组合而非桌面本身的要求，不放能力聚合里。

    # gvfs：文件管理、回收站、网络共享（mkDefault：主机可普通赋值关闭）
    services.gvfs.enable = lib.mkDefault true;

    # 以下三项原先由 GNOME 会话模块顺带打开（mkDefault），本仓库不再装 GNOME 会话后
    # 显式声明——它们与 GNOME 无关，而是桌面/音视频栈真正需要的：
    services.upower.enable = lib.mkDefault true; # 电源/电量状态（Noctalia 电量控件、笔记本）
    services.avahi.enable = lib.mkDefault true; # mDNS 局域网发现（LocalSend、网络打印机）
    security.rtkit.enable = lib.mkDefault true; # PipeWire 实时优先级（缺它时高负载下会垚音）
    # 故意不跟着开的（GNOME 曾经顺带打开，均已确认本机无用）：
    #   colord（ICC 色彩管理）geoclue2（浏览器定位）services.hardware.bolt（雷电
    #   设备授权）power-profiles-daemon（笔记本用 TLP、游戏用 gamemode）
    #   gnome-remote-desktop（RDP 服务端）：要远程访问时单独开
    #   services.gnome.gnome-remote-desktop

    # 输入法（系统层面）
    i18n.inputMethod = {
      enable = true;
      type = "fcitx5";
      fcitx5 = {
        waylandFrontend = true;
        addons = with pkgs; [
          kdePackages.fcitx5-configtool
          kdePackages.fcitx5-qt
          fcitx5-gtk
          # 水杉输入法（msime-fcitx5）：插件本身 + msime-linux-setup 首次配置入口。
          # 词库不随包，装后由每个用户跑一次 `msime-linux-setup --download`
          # 或打开「水杉输入法」设置完成首次配置（见 docs/input.md）
          msime-fcitx5
          # 候选词窗主题不在此选择：仓库不托管 classicui.conf，用 fcitx5 内置默认
        ];
      };
    };

    # 确保 fcitx5 在登录时自动启动
    services.xserver.desktopManager.runXdgAutostartIfNone = true;

    # 输入法环境变量：不设 GTK_IM_MODULE/QT_IM_MODULE——原生 Wayland 应用
    # 走 text-input-v3 → niri（input-method-v2 中转）→ fcitx5 classicui 画
    # 候选窗，即上游在 fcitx5-gtk PR #44 指明的路线（fcitx5-gtk 的
    # client-side popover 及其复刻的主题渲染上游已宣布不维护）。XWayland
    # 应用不靠全局变量：Qt 侧由 lib.wrapQtXWayland 按应用注入，其余 X11
    # 应用靠 XIM（XMODIFIERS 兜底）。注意：nixpkgs 的 fcitx5 模块把
    # XMODIFIERS 只写进 environment.variables（登录 shell 可见、到不了
    # 图形会话），因此这里仍需手动补齐。
    environment.sessionVariables = {
      XMODIFIERS = "@im=fcitx";
      SDL_IM_MODULE = "fcitx";
      GLFW_IM_MODULE = "fcitx";
      NIXOS_OZONE_WL = "1";
    };

    # GTK/Qt 主题包（运行时按名字解析，必须在系统 profile 里）
    environment.systemPackages = with pkgs; [
      xwayland-satellite
      gnome-themes-extra
      papirus-icon-theme
      bibata-cursors
      # 首次配置入口 msime-linux-setup（词库不随包，装后每个用户跑一次）
      msime-fcitx5

      # bubblewrap：Qoder IDE 终端沙箱的运行时依赖，与 distrobox/podman 同类。
      # Qoder 按 PATH 探测 bwrap，探测不到即报「Bubblewrap 未安装」并关掉该功能；
      # 而它自己那层 FHS 包装器（~/Apps/Qoder-IDE/qoder-ide-fhs.nix）用 store 绝对
      # 路径调 bwrap，所以「IDE 起得来」并不等于「PATH 上有 bwrap」。
      # 放系统 profile 而非 HM 的 common/tools：后者门控是 myHome.cli.enable，
      # server / wsl / macbook 四个角色全都开，会把桌面专属依赖带到无 GUI 的主机上。
      bubblewrap
    ];
  };
}
