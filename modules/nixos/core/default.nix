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
  # 主用户名（选项定义在 users.nix）：trusted-users、autoUpgrade 提交身份等
  # 均由此派生，避免用户名散落硬编码
  primaryUser = config.mySystem.primaryUser;
in
{
  # mySystem 选项命名空间 — 各主机通过设置这些选项来声明启用的功能
  options.mySystem = {
    hardware.enable = lib.mkEnableOption "硬件支持（蓝牙、音频、网络）";
    desktop.enable = lib.mkEnableOption "桌面环境（GDM、Niri、GNOME）";
    virtualization.enable = lib.mkEnableOption "QEMU/KVM 虚拟化";
    # 本机 flake 仓库路径（autoUpgrade / git safe.directory 用）。默认假设仓库
    # 在主用户 Projects 目录下（所有主机的既有布局）；机器布局不同时覆盖此项，
    # 不必改共享模块。
    configDir = lib.mkOption {
      type = lib.types.str;
      default = "${config.users.users.${primaryUser}.home}/Projects/nixos-config";
      description = "本机 flake 仓库路径（autoUpgrade 与 nixos-upgrade 提交 flake.lock 的目标）";
    };
  };

  imports = [
    ./users.nix
    ./locale.nix
    # Nix 设置 / 镜像源 / overlay 注入的平台无关部分（与 darwin 共享）
    ../../shared/nix.nix
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
      flake = "${config.mySystem.configDir}#${config.networking.hostName}";
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
      repo="${config.mySystem.configDir}"
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

    # experimental-features / 镜像源 / 公钥 / allowUnfree / overlay 注入：
    # 平台无关部分在共享模块 ../../shared/nix.nix（darwin 同源），此处只留
    # NixOS 专属增量（trusted-users、GC）。nixpkgs 的 config/nix.nix 会 mkAfter
    # 追加官方源并无条件提供 root 用户，故共享模块不写 cache.nixos.org。
    nix.settings = {
      connect-timeout = 5;
      # 充分利用多核 CPU 加速构建
      max-jobs = "auto";
      cores = 0;
      # 保留 derivations 和 outputs 的依赖关系，避免重复构建
      keep-outputs = true;
      keep-derivations = true;
      # root 由 nixpkgs 提供，此处只加主用户
      trusted-users = [ primaryUser ];
    };

    # 硬件加速（Mesa/Vulkan 用户态驱动）。是「硬件能力」而非系统基础：
    # 服务器（mySystem.hardware.enable 不开）不需要图形栈，放在 hardware 域
    # 聚合（../hardware/default.nix）用 mkDefault 给默认值，core 本身不启用。
    # 保留此处引用关系说明：desktop 域的 niri / 硬件域的 NVIDIA 都依赖它。

    # FHS 兼容：所有 NixOS 主机的系统基础（服务器也要跑闭源/预编译二进制）
    programs.nix-ld.enable = true;

    # 系统总线
    services.dbus = {
      enable = true;
      implementation = "broker";
    };

    # 允许非自由软件
    nixpkgs.config.allowUnfree = true;

    # 允许不安全的包（每条须写明被哪个包需要，并定期复核是否仍有效）
    nixpkgs.config.permittedInsecurePackages = [
      # zotero 10 的运行时 Firefox ESR 140 已于 2026-10-13 EOL（nixpkgs 标记 insecure）
      "firefox-esr-140-bin-unwrapped-140.17.0esr"
    ];

    # NUR overlay 与自定义包 overlay 由共享模块 ../../shared/nix.nix 统一注入
    # （与 darwin 同源）。此处只加水杉输入法的 Fcitx5 插件：插件加载进 fcitx5
    # 进程，必须按本系统的 nixpkgs 构建，才能与系统上的 Fcitx5 出自同一份
    # （消费方见 ../desktop）。fixNoticeLists 补上游 notice 两表错位
    # （frontend-npm-NOTICES.txt 装不出来 → installCheckPhase 失败），
    # 见 pkgs/msime-fcitx5 补丁头与 docs/quirks.md。
    nixpkgs.overlays = [
      (final: prev: {
        msime-fcitx5 =
          (inputs.msime.overlays.default final prev).msime-fcitx5.overrideAttrs
            (previousAttrs: {
              patches = (previousAttrs.patches or [ ]) ++ [
                ../../../pkgs/msime-fcitx5/notice-lists-alignment.patch
              ];
            });
      })
    ];

    # nixos-upgrade.service 以 root 运行且 HOME=/root，读不到用户 ~/.gitconfig，
    # libgit2 因仓库属主非 root 而拒绝访问。必须在系统级 /etc/gitconfig 放开
    # safe.directory，否则 autoUpgrade 每日必然失败。
    # programs.git.enable 默认为 false：不开启则 /etc/gitconfig 根本不会生成。
    programs.git.enable = true;
    programs.git.config.safe.directory = [
      config.mySystem.configDir
    ];

    # SSH（所有 NixOS 主机的基础：服务器也要远程管理）
    services.openssh = {
      enable = true;
      settings = {
        # 允许密码登录：有意为之——SSH 仅用于局域网登录，不暴露公网。
        # server 角色（modules/nixos/profiles/server.nix）面向不可信网络，
        # 会用 mkForce 关掉密码认证改走密钥；其它角色沿用此默认。
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
      wget
    ];

    system.stateVersion = "26.05";
  };
}
