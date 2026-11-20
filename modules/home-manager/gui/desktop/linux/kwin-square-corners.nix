# KDE 窗口直角装饰
#
# 混用圆角的来源有两条独立的装饰路径：
#   - KWin 服务端装饰（KDE/Qt 窗口）：走 Aurorae 的 WhiteSur-dark
#   - GTK 客户端装饰（GTK3/浏览器等）：走 MacTahoe 自己的 CSD
# 两条路径各自有各自的半径，KWin 也不会替 GTK 裁角，所以统一在源头改：
#   - KWin 换 WhiteSur 的 sharp 变体，并把它仍保留的顶角补成直角
#   - MacTahoe 的顶层窗口 CSS 改为 0（见 pkgs/mactahoe-gtk-theme）
#   - Plasma 会话里让没有自定义标题栏的 GTK3 走 KWin 服务端装饰
#
# niri 不读 kwinrc，继续用 geometry-corner-radius 8 裁切窗口，行为不变。
{
  lib,
  osConfig,
  pkgs,
  ...
}:
let
  # nixpkgs 的 whitesur-kde 只安装默认圆角变体。这里复用同一份上游源码和
  # postPatch，只把安装参数改成 --window sharp；sharp 的底角已是直角，顶角
  # 仍保留 12px，因此安装后再只改 Aurorae 窗口框 SVG 的四个顶角路径。
  #
  # 不能用用户目录里手工安装的 WhiteSur-Sharp-*：那份文件不在仓库里，
  # 也不随 rebuild 更新。主题名仍用上游生成的 WhiteSur-dark-sharp，和
  # 手工安装的 WhiteSur-Sharp-* 不冲突。
  whitesurKdeSquare = pkgs.whitesur-kde.overrideAttrs (old: {
    pname = "whitesur-kde-square";
    nativeBuildInputs = (old.nativeBuildInputs or [ ]) ++ [ pkgs.perl ];

    installPhase = ''
      runHook preInstall

      mkdir -p $out/doc
      name= ./install.sh --window sharp

      # 只改 active/inactive 的左上角、其水平镜像和左上角模糊 mask，不动
      # 按钮、阴影、内部控件。各 DPI 变体的路径数据相同，故一次循环覆盖
      # WhiteSur-sharp 与 WhiteSur-dark-sharp 的全部倍率。
      for svg in "$out"/share/aurorae/themes/WhiteSur-*sharp*/decoration.svg; do
        [ -e "$svg" ] || continue
        perl -0pi -e '
          s{\Qm 400,65 v 51 h 41 V 98 c 0,-6.648 5.352,-12 12,-12 h 17 V 65 Z\E}{m 400,65 v 51 h 70 V 65 Z}g;
          s{\Qm 313,201.063 c -6.648,0 -12,5.352 -12,12 v 17.93555 0.0644 h 29 v -30 z\E}{m 301,201.063 v 30 h 29 v -30 z}g;
          s{\Qm 313,201.063 c -6.648,0 -12,5.352 -12,12 v 1 c 0,-6.648 5.352,-12 12,-12 h 17 v -1 z\E}{m 301,201.063 v 1 h 29 v -1 z}g;
          s{\Qm 453,79 c -7.202,0 -13,5.798 -13,13 v 18 h 1 V 92 c 0,-6.648 5.352,-12 12,-12 h 17 v -1 z\E}{m 440,79 h 30 v 1 h -29 v 30 h -1 z}g;
          s{\Qm 40,65 v 51 H 81 V 98 c 0,-6.648 5.352,-12 12,-12 h 17 V 65 Z\E}{m 40,65 v 51 h 70 V 65 Z}g;
          s{\Qm 442,201.0625 c 6.648,0 12,5.352 12,12 v 18 h -29 v -30 z\E}{m 425,201.0625 h 29 v 30 h -29 z}g;
          s{\Qm 442,201.0625 c 6.648,0 12,5.352 12,12 v 0.59961 c 0,-6.4264 -5.352,-11.59961 -12,-11.59961 h -17 v -1 z\E}{m 425,201.0625 v 1 h 29 v -1 z}g;
          s{\Qm 93,85 c -7.202,0 -13,5.798 -13,13 v 18 h 1 V 98 c 0,-6.648 5.352,-12 12,-12 h 17 v -1 z\E}{m 80,85 h 30 v 1 h -29 v 30 h -1 z}g;
          s{\QM 400,64.99995 V 116 l 41,0 V 98 c 0,-6.648 5.352,-12 12,-12 h 17 V 64.99995 Z\E}{M 400,64.99995 V 116 h 70 V 64.99995 Z}g;
          s{\QM 400,64.99995 V 116 h 41 V 98 c 0,-6.648 5.352,-12 12,-12 h 17 V 64.99995 Z\E}{M 400,64.99995 V 116 h 70 V 64.99995 Z}g;
        ' "$svg"
      done

      runHook postInstall
    '';
  });
in
{
  config = lib.mkIf osConfig.mySystem.desktop.plasma.enable {
    home.packages = [ whitesurKdeSquare ];

    # GTK4 在 Wayland 下自己查 xdg-decoration 的 server/client 模式，KWin 已声明
    # server 模式，故它本来就会走 KWin；GTK3 仍默认自绘，显式关掉后才能吃到
    # KWin 的直角标题栏。带自定义 headerbar 的 GTK 应用仍会自绘，其顶层圆角由
    # MacTahoe 的 0px 覆盖。
    xdg.configFile."plasma-workspace/env/70-gtk-csd.sh".text = ''
      export GTK_CSD=0
    '';

    # kwinrc 的其他内容由 KWin/系统设置动态维护，这里只改装饰相关键。
    # 先写键再通知 KWin reconfigure；niri 会话没有 KWin，qdbus 失败可忽略。
    home.activation.kwinSquareCorners = lib.hm.dag.entryAfter [ "installPackages" ] ''
      $DRY_RUN_CMD ${pkgs.kdePackages.kconfig}/bin/kwriteconfig6 \
        --file "$HOME/.config/kwinrc" \
        --group org.kde.kdecoration2 \
        --key library org.kde.kwin.aurorae.v2
      $DRY_RUN_CMD ${pkgs.kdePackages.kconfig}/bin/kwriteconfig6 \
        --file "$HOME/.config/kwinrc" \
        --group org.kde.kdecoration2 \
        --key theme __aurorae__svg__WhiteSur-dark-sharp
      if [ -n "''${DBUS_SESSION_BUS_ADDRESS:-}" ]; then
        $DRY_RUN_CMD ${pkgs.kdePackages.qttools}/bin/qdbus \
          org.kde.KWin /KWin reconfigure >/dev/null 2>&1 || true
      fi
    '';
  };
}
