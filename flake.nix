{
  description = "NixOS + Niri(+Nocatalia)/Gnome 个人开发计算机";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/master";

    nur.url = "github:nix-community/NUR";

    # WinApps：把 Windows 虚拟机里的应用以独立窗口接入桌面（FreeRDP RemoteApp）。
    # 走 libvirt 后端，与 mySystem.virtualization 共用同一套 QEMU/KVM 栈。
    # 上游 flake 只提供包（无 NixOS/HM 模块），接入层由
    # modules/home-manager/gui/winapps.nix 自管。
    winapps = {
      url = "github:winapps-org/winapps";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # home-manager 跟踪 master：nixpkgs 走 master（unstable），HM release 分支
    # 与之存在 API 错位（stdenv.isLinux 弃用、fish 补全脚本路径等），master
    # 分支与 nixpkgs master 同步演进，错位随上游消失。
    home-manager = {
      url = "github:nix-community/home-manager/master";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    nixos-wsl = {
      url = "github:nix-community/NixOS-WSL";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # nix-darwin 分支须与 nixpkgs 分支匹配，否则 darwinSystem 的 release check
    # assert 会拒绝求值（nix-darwin eval-config.nix）。
    # nixpkgs 跟踪 master（unstable），故 nix-darwin 也用 master。
    nix-darwin = {
      url = "github:nix-darwin/nix-darwin/master";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    noctalia = {
      url = "github:noctalia-dev/noctalia-shell";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # 水杉输入法（MSIME）的 Linux 宿主：Fcitx5 插件、命令行入口与 provider 用户单元。
    # 插件被加载进 fcitx5 进程，必须与系统上的 Fcitx5 出自同一份 nixpkgs，
    # 故经 overlay 接入（见 modules/nixos/core/default.nix）。
    msime = {
      url = "github:metasequoiaime/msime";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # zen 浏览器（not in nixpkgs）
    # 使用二次打包（固定输出模式下载程序+Firefox封装脚本）
    zen-browser = {
      url = "github:0xc000022070/zen-browser-flake";
      inputs.nixpkgs.follows = "nixpkgs";
      # 复用 HM's 火狐浏览器模块
      inputs.home-manager.follows = "home-manager";
    };
  };

  outputs =
    {
      self,
      nixpkgs,
      nur,
      noctalia,
      home-manager,
      nixos-wsl,
      nix-darwin,
      ...
    }@inputs:
    let
      lib = nixpkgs.lib;
      myLib = import ./lib { inherit lib; };

      # Home Manager 共享样板（NixOS 与 darwin 同一份）：减少每个主机重复的接线。
      # useGlobalPkgs = true：HM 直接复用系统级 nixpkgs 实例（含 core 注入的
      # NUR 与自定义包 overlay），overlay 与 allowUnfree 只在系统级维护一处。
      # 用户名不硬编码：取值方式由调用方给出，默认取 mySystem.primaryUser，
      # darwin 侧改取 nix-darwin 的 system.primaryUser。
      # 角色由 profile 参数指定（modules/home-manager/profiles/）：各角色决定
      # 导入哪些能力层（common / dev / gui apps / desktop 会话），主机不再自拼。
      mkHomeManager =
        {
          profile,
          extraModules ? [ ],
          primaryUser ? (cfg: cfg.mySystem.primaryUser),
        }:
        { config, ... }:
        {
          home-manager.useGlobalPkgs = true;
          home-manager.useUserPackages = true;
          home-manager.backupFileExtension = "hm-bak";
          home-manager.extraSpecialArgs = { inherit inputs myLib; };
          home-manager.users.${primaryUser config}.imports = [
            ./modules/home-manager
            profile
          ]
          ++ extraModules;
        };

      # 所有 NixOS 主机共享的核心模块（真正的系统基础，见 modules/nixos/core）
      nixosCore = [
        ./modules/nixos/core
        home-manager.nixosModules.home-manager
        # nixos-rebuild-ng 不再自动注入 revision，需 flake 显式声明，
        # 否则 systemd-boot 菜单与 nixos-version --configuration-revision 只能显示 Unknown
        { system.configurationRevision = self.rev or "dirty"; }
      ];

      # NixOS 角色模块（系统层）：决定某类设备启用哪些系统能力。
      # 主机套用对应角色后再追加硬件差异，不再自己拼系统能力组合。
      nixosProfiles = {
        workstation = ./modules/nixos/profiles/workstation.nix;
        server = ./modules/nixos/profiles/server.nix;
        wsl = ./modules/nixos/profiles/wsl.nix;
      };
    in
    {
      # ==========================================
      # NixOS 配置
      # ==========================================
      nixosConfigurations = {
        # 台式机（Niri 桌面）— workstation 角色
        desktop = nixpkgs.lib.nixosSystem {
          system = "x86_64-linux";
          specialArgs = { inherit inputs myLib; };
          modules = nixosCore ++ [
            nixosProfiles.workstation
            ./hosts/desktop
            (mkHomeManager { profile = ./modules/home-manager/profiles/workstation.nix; })
          ];
        };

        # 笔记本（Niri 桌面）— workstation 角色
        laptop = nixpkgs.lib.nixosSystem {
          system = "x86_64-linux";
          specialArgs = { inherit inputs myLib; };
          modules = nixosCore ++ [
            nixosProfiles.workstation
            ./hosts/laptop
            (mkHomeManager { profile = ./modules/home-manager/profiles/workstation.nix; })
          ];
        };

        # 服务器（无桌面）— server 角色
        server = nixpkgs.lib.nixosSystem {
          system = "x86_64-linux";
          specialArgs = { inherit inputs myLib; };
          modules = nixosCore ++ [
            nixosProfiles.server
            ./hosts/server
            (mkHomeManager { profile = ./modules/home-manager/profiles/server.nix; })
          ];
        };

        # WSL（仅 CLI/TUI）— wsl 角色
        wsl = nixpkgs.lib.nixosSystem {
          system = "x86_64-linux";
          specialArgs = { inherit inputs myLib; };
          modules = nixosCore ++ [
            nixosProfiles.wsl
            ./hosts/wsl
            (mkHomeManager { profile = ./modules/home-manager/profiles/wsl.nix; })
          ];
        };

      };

      # ==========================================
      # macOS 配置
      # ==========================================
      darwinConfigurations = {
        # MacBook — macbook 角色（HM 侧导入 common + dev + 跨平台 GUI 应用配置）
        macbook = nix-darwin.lib.darwinSystem {
          system = "aarch64-darwin";
          specialArgs = { inherit inputs myLib; };
          modules = [
            # macOS 共享层（base/users/gui）统一收口在 modules/darwin，
            # 与 NixOS 侧「共享配置在 modules/、主机差异在 hosts/」的约定对齐
            ./modules/darwin
            ./hosts/macbook

            home-manager.darwinModules.home-manager
            # 与 NixOS 侧共用同一份接线；darwin 的用户名来源是 system.primaryUser
            (mkHomeManager {
              profile = ./modules/home-manager/profiles/macbook.nix;
              primaryUser = cfg: cfg.system.primaryUser;
            })
          ];
        };
      };

      # ==========================================
      # 自定义包与 overlay
      # ==========================================
      # packages 供 `nix build .#<name>` 单独构建验证某个自维护包；overlays 供
      # 外部 flake 复用。两者与系统级注入（modules/nixos/core 与 modules/darwin/base
      # 的 nixpkgs.overlays）共用同一份 overlays/default.nix，包清单只维护这一处。
      # nix flake check 会逐一评估 packages.*，nixpkgs 滚动带来的包级回归
      # （fetch 哈希失配、依赖 API 变更）在 CI 即暴露，不再只靠主机 dry-build 兜底。
      overlays.default = import ./overlays { inherit inputs; };

      packages =
        let
          # 把 overlay 直接应用到 legacyPackages，得到自定义包的属性集
          customPkgs =
            system:
            (import ./overlays { inherit inputs; }) nixpkgs.legacyPackages.${system}
              nixpkgs.legacyPackages.${system};
        in
        myLib.forAllSystems (
          system:
          let
            pkgs = nixpkgs.legacyPackages.${system};
          in
          # 按各包 meta.platforms 过滤（如 windows-vm-media 仅 linux），
          # 避免在不支持的平台上评估必败的包
          lib.filterAttrs (_: pkg: lib.meta.availableOn pkgs.stdenv.hostPlatform pkg) (customPkgs system)
        );

      # ==========================================
      # 检查（nix flake check / CI 会逐一执行）
      # ==========================================
      # niri 配置校验：niri 的用户配置走 mkOutOfStoreSymlink 直连 git 工作树，
      # 编辑即生效、无代际回滚，改坏配置要到下次登录才暴露。这里把静态部分
      # （仓库内 config/ 目录）与求值生成的部分（niri-colors / niri-outputs）
      # 按真实布局拼装后跑 `niri validate`，把语法/结构错误拦在提交阶段。
      # 主机清单不硬编码：从 nixosConfigurations 枚举开了 niri 的主机。
      checks =
        let
          # niri 校验只在 linux 桌面主机上有意义（niri 为 linux-only 包）
          pkgs = nixpkgs.legacyPackages.x86_64-linux;
          niriHosts = lib.filterAttrs (_: c: c.config.mySystem.desktop.niri.enable) self.nixosConfigurations;
          mkNiriValidate =
            host:
            let
              hostCfg = self.nixosConfigurations.${host}.config;
              hmUser = hostCfg.home-manager.users.${hostCfg.mySystem.primaryUser};
              # config.kdl 的 include 对 ~ 展开到 $HOME，相对路径以 config.kdl
              # 所在目录为基准——按真实布局放置后整目录拷出再校验
              mkKdl = name: pkgs.writeText (baseNameOf name) hmUser.xdg.configFile.${name}.text;
            in
            pkgs.runCommand "niri-validate-${host}"
              {
                nativeBuildInputs = [ pkgs.niri ];
              }
              ''
                set -eu
                export HOME="$PWD/home"
                mkdir -p "$HOME/.config/niri-colors" "$HOME/.config/niri-outputs"
                cp ${mkKdl "niri-colors/layout.kdl"}   "$HOME/.config/niri-colors/layout.kdl"
                cp ${mkKdl "niri-colors/overview.kdl"} "$HOME/.config/niri-colors/overview.kdl"
                cp ${mkKdl "niri-outputs/outputs.kdl"} "$HOME/.config/niri-outputs/outputs.kdl"
                cp -r ${./modules/home-manager/gui/desktop/linux/niri/config} conf
                chmod -R u+w conf
                niri validate -c conf/config.kdl
                touch "$out"
              '';
        in
        {
          x86_64-linux = lib.mapAttrs' (
            host: _: lib.nameValuePair "niri-validate-${host}" (mkNiriValidate host)
          ) niriHosts;
        };

      # ==========================================
      # 开发 Shell
      # ==========================================
      devShells = myLib.forAllSystems (
        system:
        let
          pkgs = nixpkgs.legacyPackages.${system};
        in
        {
          default = pkgs.mkShell {
            packages = [
              pkgs.git
              # treefmt 封装：整树/目录格式化（nix fmt 裸调用走的就是它）
              pkgs.nixfmt-tree
              # 裸 nixfmt：编辑器 format-on-save 等单文件场景（stdin 模式）
              pkgs.nixfmt
            ];
          };
        }
      );

      # 格式化配置：nixfmt（RFC 166 风格，nixpkgs 官方采纳；nixpkgs-fmt 上游
      # 已归档停更，2026-09 迁移）。用 nixfmt-tree 包装器而非裸 nixfmt：
      # nixfmt 1.5 起裸调用（无参数）只读 stdin，`nix fmt` 会空转报错；
      # nixfmt-tree 基于 treefmt，裸调用即递归格式化当前目录全部 .nix 文件。
      formatter = myLib.forAllSystems (system: nixpkgs.legacyPackages.${system}.nixfmt-tree);
    };
}
