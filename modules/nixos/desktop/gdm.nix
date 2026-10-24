# GDM 登录管理器（含登录界面换肤）
#
# 本仓库不再安装 GNOME 会话（只留 GDM 做登录器 + Niri 会话），所以这里同时承担
# 登录界面的外观：背景 + gnome-shell 主题。greeter 用的 gnome-shell 由 GDM 自己
# 的闭包提供，与用户会话无关。
{
  lib,
  config,
  pkgs,
  myLib,
  ...
}:
let
  cfg = config.mySystem.desktop;

  # 登录界面与桌面会话共用一套外观：字体 / 图标 / 光标 + 壁纸。
  #
  # 字体与图标必须显式声明：主题包与图标包虽然在 gdm 的 extraPackages 里（能解析到），
  # 但 MacTahoe 的 gnome-shell.css 不含 font-family 声明，不写这条 greeter 就会用
  # GSettings 默认（Adwaita Sans / Adwaita 图标），与桌面上的 HarmonyOS Sans SC /
  # MacTahoe-dark 对不上。
  # cursor-size 必须用 gvariant 带类型 —— toDconfINI 拒绝裸 int。
  #
  # 背景取 store 路径（wallpapers 首项）而不是 ~/Pictures 里那份部署副本：greeter 的
  # systemd 单元受限、且 store 路径世界可读、不可变。深色变体一并设：greeter 恒为
  # 深色，GNOME 42+ 在深色模式下读 picture-uri-dark 而不是 picture-uri。
  greeterDatabases = [
    {
      settings."org/gnome/desktop/interface" = {
        font-name = "${myLib.theme.fontSans} 12";
        icon-theme = "MacTahoe-dark";
        cursor-theme = myLib.theme.cursor;
        cursor-size = lib.gvariant.mkInt32 24;
      };
    }
  ]
  ++ lib.optionals (cfg.wallpapers != [ ]) [
    {
      settings."org/gnome/desktop/background" = {
        picture-uri = "file://${lib.head cfg.wallpapers}";
        picture-uri-dark = "file://${lib.head cfg.wallpapers}";
      };
    }
  ];
in
{
  config = lib.mkIf cfg.enable {
    # 启用 GDM 作为显示管理器
    services.displayManager.gdm.enable = true;

    # 登录界面换肤（MacTahoe）。
    # gnome-shell 的 gnome-shell-theme.gresource 路径在编译期烘进二进制，运行时
    # 读的是本包 store 路径下的同名文件，只能通过覆盖 gnome-shell 包替换
    # gresource（一次重建，代价较高）。覆盖作用于所有消费者，GDM 的 greeter
    # 随之变 MacTahoe —— 用户会话里没有 GNOME，不存在两套 shell 不一致的问题。
    nixpkgs.overlays = [
      (final: prev: {
        gnome-shell = prev.gnome-shell.overrideAttrs (old: {
          postFixup = (old.postFixup or "") + ''
            cp ${final.mactahoe-gtk-theme}/share/gnome-shell/gnome-shell-theme.gresource \
              $out/share/gnome-shell/gnome-shell-theme.gresource
          '';
        });
      })
    ];

    # 主题/图标包加入 GDM 的 XDG_DATA_DIRS，登录界面可解析 MacTahoe 资源
    services.displayManager.gdm.extraPackages = [
      pkgs.mactahoe-gtk-theme
      pkgs.mactahoe-icon-theme
    ];

    # 登录界面与桌面会话共用同一张壁纸，见 docs/themes.md 的壁纸一节
    programs.dconf.profiles.gdm.databases = greeterDatabases;
  };
}
