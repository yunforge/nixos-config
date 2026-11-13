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

    # 预编译浏览器的共享库。agent-browser / Playwright 下载的 Chrome for Testing
    # 没有 RPATH，且 NixOS 没有 apt/dnf/yum —— `install --with-deps` 必然失败。
    # 交给 nix-ld 注入 NIX_LD_LIBRARY_PATH 后，下载来的 Chrome 可直接启动，
    # 不再需要各处 export LD_LIBRARY_PATH。清单对应 Chrome 的直接依赖
    # （headless 与 headed 共用部分）；上游新增依赖时在此补一行。
    programs.nix-ld.libraries = with pkgs; [
      alsa-lib
      at-spi2-core
      cairo
      cups
      dbus
      expat
      fontconfig
      freetype
      gdk-pixbuf
      glib
      gtk3
      libdrm
      libgbm
      libx11
      libxcb
      libxcomposite
      libxcursor
      libxdamage
      libxext
      libxfixes
      libxi
      libxinerama
      libxkbcommon
      libxrandr
      libxrender
      libxshmfence
      nspr
      nss
      pango
      systemdLibs
    ];

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
    # （消费方见 ../desktop）。msimeLibFixed 补上游 nix 打包 fileset 白名单漏掉的
    # 根目录文件（见下方注释与 docs/quirks.md）。
    nixpkgs.overlays = [
      (final: prev: {
        msime-fcitx5 =
          let
            # msime 0.16.0 的 Cargo.lock 新增两个 git 依赖：llama-cpp-2 /
            # llama-cpp-sys-2（git 源 utilityai/llama-cpp-rs，其子模块指向
            # ggml-org/llama.cpp）与 tauri-nspanel。上游 nix 打包没给
            # outputHashes，crane 便在 hash == null 时退回 builtins.fetchGit
            # { submodules = true; }——求值期联网、非固定输出，且 Nix 对子模块
            # 用 allRefs 抓全部 ref：llama.cpp 有 2.8 万个 ref（1.9 万 PR +
            # 8463 tag），实测 600 MB、经代理中途 eof 断开，主机 rebuild 直接
            # 失败在求值阶段。补上 outputHashes 后 crane 改走 pkgs.fetchgit
            # （浅抓 pin 住的 rev、固定输出、进 store 可缓存），求值期不再联网。
            # 哈希由 nix-prefetch-git --fetch-submodules 实算，升级 msime 后
            # Cargo.lock 的 rev 变了要重算（命令见 docs/quirks.md）。
            # 上游补上 outputHashes 后整段可删。
            msimeGitOutputHashes = {
              "git+https://github.com/utilityai/llama-cpp-rs.git?rev=0364f5da1c6a6ee37f507031f116ce4a09b28594#0364f5da1c6a6ee37f507031f116ce4a09b28594" =
                "sha256-7jI4+6tJ6s69ojMeqUbDHbbUfmlMbnecpvWrTM7iLEM=";
              "git+https://github.com/ahkohd/tauri-nspanel?rev=c9ec2130422200f0863b23dfdad02b133a529b07#c9ec2130422200f0863b23dfdad02b133a529b07" =
                "sha256-cyv+i5uhtHNO5YmKnT/fmRO7dT3F9+K/js7ToxZh5DA=";
            };
            msimeCrane = inputs.msime.inputs.crane // {
              mkLib =
                p:
                (inputs.msime.inputs.crane.mkLib p).overrideScope (
                  _craneFinal: cranePrev: {
                    vendorCargoDeps =
                      args:
                      cranePrev.vendorCargoDeps (
                        args // { outputHashes = msimeGitOutputHashes // (args.outputHashes or { }); }
                      );
                  }
                );
            };
            # 与 inputs.msime.overlays.default 等价（同一份 platforms/linux/nix
            # 的 packages），只把 crane 换成带 outputHashes 的那份。
            msimePkgs =
              (import (inputs.msime.outPath + "/platforms/linux/nix") {
                pkgs = final;
                crane = msimeCrane;
                rust-overlay = inputs.msime.inputs.rust-overlay;
              }).packages;
            # 上游 nix 打包全靠 lib.fileset 白名单选源码（default.nix 的 cargoSources、
            # desktop.nix 的前端 src 等），而 2026-10-24/25 的提交让 crates 与 packages/ui
            # 引用了白名单外的根目录文件：plugins/phrase_table/latex-symbols/symbols.tsv
            # （engine/symbol_groups.rs include_str!，c289dd69）与
            # resources/keyboard-skin-presets.json（packages/ui 皮肤预设，da0e42f7）。
            # 文件在上游 git 树里存在、构建树里没有 → cargo 报 include_str! 找不到、
            # vite 报 Module not found。给这层 lib 的 fileset.toSource 包一层，统一把
            # 两个文件并进白名单，经 .override { lib } 作用于 host-api/mcp/desktop
            # 三个包（fcitx5 自身 src 不缺文件，不动）。上游修好 fileset 后整段 let
            # 可删；多并的文件对修好的上游是幂等的。
            msimeLibFixed = prev.lib.extend (
              lself: lprev: {
                fileset = lprev.fileset // {
                  toSource =
                    args@{ root, fileset }:
                    lprev.fileset.toSource (
                      args
                      // {
                        fileset = lprev.fileset.unions [
                          fileset
                          (root + "/resources/keyboard-skin-presets.json")
                          (root + "/plugins/phrase_table/latex-symbols/symbols.tsv")
                        ];
                      }
                    );
                };
              }
            );
          in
          msimePkgs.msime-fcitx5.override {
            settingsWindow = msimePkgs.msime-desktop.override { lib = msimeLibFixed; };
            "msime-host-api" = msimePkgs.msime-host-api.override { lib = msimeLibFixed; };
            "msime-mcp" = msimePkgs.msime-mcp.override { lib = msimeLibFixed; };
          };
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

    # 防火墙（3425：Magpie 网关，供局域网客户端使用）
    networking.firewall.allowedTCPPorts = [
      22
      3425
    ];

    # 系统级包
    environment.systemPackages = with pkgs; [
      wget
    ];

    system.stateVersion = "26.05";
  };
}
