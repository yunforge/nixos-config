# NixOS 核心配置（所有 NixOS 主机共享）
# 定义 mySystem 选项命名空间，导入所有子模块
{
  config,
  pkgs,
  lib,
  inputs,
  ...
}:
let
  # 主用户名（选项定义在 users.nix）：configDir、trusted-users、autoUpgrade
  # 提交身份等均由此派生，避免用户名散落硬编码
  primaryUser = config.mySystem.primaryUser;
  # 本机 flake 仓库路径（所有 NixOS 主机统一放在用户 Projects 目录下）
  configDir = "${config.users.users.${primaryUser}.home}/Projects/nixos-config";
in
{
  # mySystem 选项命名空间 — 各主机通过设置这些选项来声明启用的功能
  options.mySystem = {
    hardware.enable = lib.mkEnableOption "硬件支持（蓝牙、音频、网络）";
    desktop.enable = lib.mkEnableOption "桌面环境（GDM、Niri、GNOME）";
    virtualization.enable = lib.mkEnableOption "QEMU/KVM 虚拟化";
  };

  imports = [
    ./users.nix
    ./locale.nix
    ../hardware
    ../desktop
    ../virtualization
    ../networking
  ];

  config = {
    # ==========================================
    # Boot
    # ==========================================
    boot.loader.systemd-boot.enable = lib.mkIf (!config.boot.isContainer) (lib.mkDefault true);
    # 保留历史版本数量：10
    boot.loader.systemd-boot.configurationLimit = lib.mkDefault 10;
    # 控制台分辨率取固件支持的最高模式。默认的 "keep" 会沿用固件选的低分辨率
    # （本机实测 128x48 网格），该信号被 4K 显示器放大铺满整屏 → 开机日志字极大；
    # nvidia 接管控制台后切到原生 3840x2160（240x67），关机日志字恢复正常大小，
    # 两段不一致。取最高模式让早期控制台也跑原生分辨率，两段观感一致。
    boot.loader.systemd-boot.consoleMode = lib.mkDefault "max";
    boot.loader.efi.canTouchEfiVariables = lib.mkIf (!config.boot.isContainer) (lib.mkDefault true);
    # WSL2 内核由 Windows 宿主提供，容器内设置此项无功能影响
    boot.kernelPackages = lib.mkIf (!config.boot.isContainer) pkgs.linuxPackages_latest;

    # 保持NixOS系统自动更新
    # 必须显式指向本机 flake：未设 flake 时 nixos-rebuild 回退 classic 路径，
    # 而本机 NIX_PATH 无 nixos-config，daily timer 只会反复失败。
    # 各主机 networking.hostName 与 flake 输出属性同名，据此自动选择目标主机。
    system.autoUpgrade = {
      enable = true;
      allowReboot = false;
      flake = "${configDir}#${config.networking.hostName}";
      # 显式钉死 --refresh：nixpkgs 默认 flags 已含此项，此处重复声明仅为
      # 防止上游变更默认值后退化为只构建 flake.lock 锁定的旧 nixpkgs
      flags = [ "--refresh" ];
    };

    # --refresh 每次都重写工作区的 flake.lock，autoUpgrade 不会提交它，工作区
    # 将永久处于脏状态：Nix 对脏树令 self.rev = null，configurationRevision
    # 退化为 "dirty"，代际随之无法回溯到 commit。升级成功后以本人身份提交
    # flake.lock 保持工作区干净。root 的 HOME=/root 无 gitconfig，故用 runuser
    # 复用用户身份提交（与上面 safe.directory 同一根源）。
    systemd.services.nixos-upgrade.postStop = ''
      [ "$SERVICE_RESULT" = "success" ] || exit 0
      repo="${configDir}"
      ${pkgs.git}/bin/git -C "$repo" diff --quiet -- flake.lock && exit 0
      ${pkgs.util-linux}/bin/runuser -u ${primaryUser} -- \
        ${pkgs.git}/bin/git -C "$repo" commit -m "chore(autoUpgrade): 刷新 flake.lock" -- flake.lock
    '';

    # 自动将超过一周的垃圾回收，降低磁盘占用
    nix.gc = {
      automatic = true;
      dates = "weekly";
      options = "--delete-older-than 7d";
    };

    # Nix 配置
    nix.settings = {
      experimental-features = [
        "flakes"
        "nix-command"
      ];
      connect-timeout = 5;
      # 充分利用多核 CPU 加速构建
      max-jobs = "auto";
      cores = 0;
      # 自动存储优化
      auto-optimise-store = true;
      # 保留 derivations 和 outputs 的依赖关系，避免重复构建
      keep-outputs = true;
      keep-derivations = true;
      # 镜像在前（国内加速）。nixpkgs 的 config/nix.nix 会 mkAfter 追加官方源
      # https://cache.nixos.org/、并无条件提供 root 用户与 cache.nixos.org 公钥，
      # 故此处只声明增量，避免合并后出现重复项；与 darwin 侧
      # （modules/darwin/base.nix）的镜像顺序保持一致
      substituters = [
        "https://mirrors.tuna.tsinghua.edu.cn/nix-channels/store"
        "https://mirrors.ustc.edu.cn/nix-channels/store"
        "https://nix-community.cachix.org"
      ];
      trusted-public-keys = [
        "nix-community.cachix.org-1:mB9FSh9qf2dCimDSUo8Zy7bkj5bg+wLbWLCTCfOj2Wc="
      ];
      # root 由 nixpkgs 提供，此处只加主用户
      trusted-users = [ primaryUser ];
    };

    # 硬件加速
    hardware.graphics.enable = true;

    # FHS 兼容
    programs.nix-ld.enable = true;
    # 第三方二进制（如 ~/Downloads 里的 Tern）运行时要 dlopen 图形栈：X11
    # （libxcb/libX11/libXi/…）、Wayland（libwayland-client/libxkbcommon）与
    # Vulkan（libvulkan）。nix-ld 默认集里没有这些，裸二进制起来即 panic
    # （failed to load libxcb: libxcb.so.1: cannot open shared object file），
    # 表现为「启动器里点不开」。
    # 注意 nix-ld 的库目录是 buildEnv 平铺软链、不建闭包，故被 dlopen 的库其
    # 自身 DT_NEEDED 也要列全（libXcursor 带 libXfixes/libXrender，wayland 带
    # libffi，libglvnd 带 libGLdispatch 同一包内），否则那一个库仍是加载失败。
    # 详见 docs/quirks.md「第三方 GUI 二进制的图形栈 dlopen」条。
    programs.nix-ld.libraries = lib.mkAfter (
      with pkgs;
      [
        # X11
        libxcb
        libXau
        libXdmcp
        libX11
        libXcursor
        libXext
        libXfixes
        libXi
        libXinerama
        libXrandr
        libXrender
        # Wayland
        libxkbcommon
        wayland
        libffi
        # 显存/渲染
        libglvnd
        vulkan-loader
      ]
    );

    # 系统总线
    services.dbus = {
      enable = true;
      implementation = "broker";
    };

    # 允许非自由软件
    nixpkgs.config.allowUnfree = true;

    # 允许不安全的包（每条须写明被哪个包需要，并定期复核是否仍有效）
    nixpkgs.config.permittedInsecurePackages = [ ];

    # NUR overlay（系统级字体 harmonyos-sans 等依赖）+ 自定义包 overlay
    # （主题 / mcpp / windows-vm-media，清单见 overlays/default.nix）。
    # useGlobalPkgs = true 后 Home Manager 直接复用这份系统级实例，
    # overlay 只需在此注入一次，HM 侧不再重复维护。
    nixpkgs.overlays = [
      inputs.nur.overlays.default
      (import ../../../overlays { inherit inputs; })
    ];

    # nixos-upgrade.service 以 root 运行且 HOME=/root，读不到用户 ~/.gitconfig，
    # libgit2 因仓库属主非 root 而拒绝访问。必须在系统级 /etc/gitconfig 放开
    # safe.directory，否则 autoUpgrade 每日必然失败。
    # programs.git.enable 默认为 false：不开启则 /etc/gitconfig 根本不会生成。
    programs.git.enable = true;
    programs.git.config.safe.directory = [
      configDir
    ];

    # SSH
    services.openssh = {
      enable = true;
      settings = {
        # 允许密码登录：有意为之——SSH 仅用于局域网登录，不暴露公网。
        # 若某台主机日后需要暴露公网，应在该主机显式关闭此项并改用密钥认证。
        PasswordAuthentication = true;
        # 禁止root登录
        PermitRootLogin = "no";
      };
    };

    # 键盘布局
    services.xserver.xkb = {
      layout = "us";
    };

    # 防火墙
    networking.firewall.allowedTCPPorts = [ 22 ];

    # 系统级包
    environment.systemPackages = with pkgs; [
      iwd
      wget
    ];

    system.stateVersion = "26.05";
  };
}
