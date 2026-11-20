# KWin 快速平铺间距
#
# KWin 6.8 的 QuickRootTile 在 src/quicktile.cpp 把每个 quick tile 的
# padding 固定为 0，所以 Meta+Left/Right 与拖到屏幕边缘得到的窗口会贴住
# 工作区边缘和相邻窗口。这里用 KWin 脚本在窗口的 tile 变化时把 padding
# 设为 8：KWin 对贴屏幕边缘的一侧用全间距、对相邻窗口的一侧用半间距，
# 结果就是外缘 8 px、两块半屏之间合计 8 px，且自动避开面板与 Dock。
#
# 只对启用 Plasma 的主机生效；脚本安装在用户数据目录，不覆盖 KWin 包。
{
  lib,
  osConfig,
  pkgs,
  ...
}:
{
  config = lib.mkIf osConfig.mySystem.desktop.plasma.enable {
    xdg.dataFile = {
      "kwin/scripts/kwin-tile-gaps/metadata.json".text = builtins.toJSON {
        KPlugin = {
          Id = "kwin-tile-gaps";
          Name = "KWin Tile Gaps";
          Description = "给快速平铺窗口保留 8 px 的屏幕边缘与窗口间距";
          Version = "1.0";
          License = "MIT";
        };
        "X-Plasma-API" = "javascript";
        "X-Plasma-MainScript" = "code/main.js";
        KPackageStructure = "KWin/Script";
      };
      "kwin/scripts/kwin-tile-gaps/contents/code/main.js".source = ./kwin-tile-gaps.js;
    };

    # KWin 在登录时加载已启用的脚本。HM 激活时只写插件开关，然后让正在运行的
    # KWin 重新加载；niri 会话没有 KWin，qdbus 失败会被忽略。
    home.activation.kwinTileGaps = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
      $DRY_RUN_CMD ${pkgs.kdePackages.kconfig}/bin/kwriteconfig6 \
        --file "$HOME/.config/kwinrc" \
        --group Plugins \
        --key kwin-tile-gapsEnabled true
      if [ -n "''${DBUS_SESSION_BUS_ADDRESS:-}" ]; then
        $DRY_RUN_CMD ${pkgs.kdePackages.qttools}/bin/qdbus \
          org.kde.KWin /KWin reconfigure >/dev/null 2>&1 || true
      fi
    '';
  };
}
