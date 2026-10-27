# Steam 游戏平台 — 系统级配置（仅 desktop 游戏机）
# gamescope/MangoHud/GameMode 注入 Steam FHS 环境，游戏启动项可直接用 mangohud / gamemoderun
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
  options.mySystem.desktop.steam.enable = lib.mkEnableOption "Steam 游戏平台";

  config = lib.mkIf (cfg.enable && cfg.steam.enable) {
    programs.steam = {
      enable = true;
      # Steam 桌面 UI（steamwebhelper / CEF）的缩放独立于 niri：新版直接从
      # X11 的 Xft.dpi 读缩放档（96→1.0、144→1.5），而混合缩放屏会被
      # xwayland-satellite 压到最小 scale（见 docs/quirks.md「混合缩放屏」），
      # 于是 UI 明显偏小。STEAM_FORCE_DESKTOPUI_SCALING 是上游提供的显式
      # 覆盖（2023 界面改版起支持小数），按桌面声明的 scale 注入，使其不再
      # 依赖 Xft.dpi。注意客户端内「界面 → 根据显示器大小放大文字和图标」
      # 需保持开启，否则该值不生效。
      #
      # 用 extraProfile 而非 extraEnv：steam 的 extraEnv 会被原样转交给
      # buildFHSEnv，而后者没有这个参数（removeAttrs 静默丢弃），实测产物
      # 的 /etc/profile 里查不到；extraProfile 才是真正写进 fhsenv 的通路。
      package = pkgs.steam.override {
        extraProfile = ''
          export STEAM_FORCE_DESKTOPUI_SCALING=${builtins.toJSON cfg.scale}
        '';
      };
      # 注入 Steam FHS 环境：游戏内启动项可写 mangohud %command% / gamemoderun %command%
      extraPackages = with pkgs; [
        gamescope
        gamemode
        mangohud
      ];
      # 局域网串流 / 局域网游戏转移（放行防火墙端口）
      remotePlay.openFirewall = true;
      localNetworkGameTransfers.openFirewall = true;
    };

    # 手柄/控制器 udev 规则（Xbox、Steam Controller 等）
    hardware.steam-hardware.enable = true;

    # GameMode 提频守护进程（gamemoderun 提升 CPU governor、降低进程 nice）
    programs.gamemode.enable = true;
  };
}
