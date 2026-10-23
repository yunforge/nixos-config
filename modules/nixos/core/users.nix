# NixOS 用户配置（带 options）
# 主机可在 default.nix 中覆盖 mySystem.users.<name> 来定制用户
{
  lib,
  config,
  pkgs,
  ...
}:
{
  # 主用户：configDir、trusted-users、home-manager 集成等
  # 系统级接线均由此派生（见 core/default.nix 与 flake.nix 的 mkHomeManager），
  # 改用户名只动这一处。
  options.mySystem.primaryUser = lib.mkOption {
    type = lib.types.str;
    default = "yunforge";
    description = "主用户名：系统级接线（flake 路径、trusted-users、HM 集成）由此派生";
  };

  options.mySystem.users = lib.mkOption {
    type = lib.types.attrsOf (
      lib.types.submodule {
        options = {
          enable = lib.mkEnableOption "此用户";
          extraGroups = lib.mkOption {
            type = lib.types.listOf lib.types.str;
            default = [ ];
            description = "用户附加组";
          };
          shell = lib.mkOption {
            type = lib.types.package;
            default = pkgs.fish;
            description = "用户默认 Shell";
          };
          # 以下两项钉死数值身份，改名时不被重新分配：
          # NixOS 按「用户名」查 uid-map 复用旧 UID，换名字即视为新用户，
          # 会从 1000 起找空号并重建 home（旧目录连同属主一起成为孤儿）；
          # rootless 容器的 subordinate ID 区间同理会被排到新段，
          # 已写入 podman 存储的 uid 映射随之错位。改名时显式写回旧值即可。
          uid = lib.mkOption {
            type = lib.types.nullOr lib.types.int;
            default = null;
            description = "固定 UID（null 表示由激活脚本自动分配）";
          };
          subIdStart = lib.mkOption {
            type = lib.types.nullOr lib.types.int;
            default = null;
            description = "rootless 容器 subordinate UID/GID 区间起始（65536 个，null 表示自动）";
          };
        };
      }
    );
    default = { };
    description = "系统用户定义";
  };

  config = {
    # 默认创建主用户（enable 用 mkDefault：主机可按需关闭）
    mySystem.users.${config.mySystem.primaryUser} = {
      enable = lib.mkDefault true;
      # 钉死数值身份（只对主用户；其它用户仍走自动分配）：
      # NixOS 的 uid-map 按「用户名」索引，改名即视为新用户，会重新分配 UID
      # 并重建 home（旧目录连同属主一起成孤儿）；rootless 容器的 subordinate
      # 区间同样会挪到新段，podman 存储里按 100000 起始写下的 uid 映射随之错位。
      # 1000 / 100000 沿用改名前的实际取值，故 /home 与容器存储无需 chown。
      # 主机若原本用别的号，覆盖这两项即可。
      uid = lib.mkDefault 1000;
      subIdStart = lib.mkDefault 100000;
      # 用户组
      extraGroups = [
        "wheel" # 允许使用sudo以管理员权限执行命令
        "audio"
        "video"
        "render"
        "input"
        "networkmanager" # NetworkManager polkit 规则授权的组，允许修改网络设置
        "libvirtd"
        "kvm"
        "i2c"
      ];
    };

    # 启用 fish
    programs.fish.enable = true;

    # 创建用户
    users.users = lib.mapAttrs' (
      name: cfg:
      lib.nameValuePair name (
        lib.mkMerge [
          (lib.mkIf cfg.enable {
            # 标识该用户为真实用户，系统自动将 group 设置为 users
            isNormalUser = true;
            extraGroups = cfg.extraGroups;
            shell = cfg.shell;
            # null 即 nixpkgs 的默认值（激活时自动分配）
            uid = cfg.uid;
          })
          (lib.mkIf (cfg.subIdStart != null) {
            # 显式区间会关掉 autoSubUidGidRange（它只在两个 ranges 均为空时默认开启）
            subUidRanges = [
              {
                startUid = cfg.subIdStart;
                count = 65536;
              }
            ];
            subGidRanges = [
              {
                startGid = cfg.subIdStart;
                count = 65536;
              }
            ];
          })
        ]
      )
    ) config.mySystem.users;
  };
}
