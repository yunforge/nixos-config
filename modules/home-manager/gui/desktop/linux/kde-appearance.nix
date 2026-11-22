# KDE 外观（仓库声明部分）
#
# Plasma 的应用程序风格、配色与面板仍归系统设置；这里只声明三类与窗口/指针
# 直接相关、且系统设置里没有稳定「一次配置」入口的项：
#   - 窗口外角：KWin 服务端装饰（KDE/Qt 窗口）走 WhiteSur sharp 变体，并把
#     其仍保留的顶角补成直角
#   - 图标主题：WhiteSur-dark（与 GTK 侧同款，见 themes/variants.nix）
#   - 光标主题：Bibata-Modern-Ice，24 逻辑像素（与 GTK/SDDM/niri 同款，
#     名字来自 lib/default.nix 的 myLib.theme.cursor）
# 快速平铺间距见同目录 kwin-tile-gaps.nix（KWin 6.8 把 quick tile padding
# 固定为 0，需要脚本补 8px）。
#
# 写入方式：rebuild 激活时用 kwriteconfig6 **逐键**写入 kwinrc / kdeglobals /
# kcminputrc —— 这三个文件的其他键由 KDE 运行时持续维护，不能整文件托管。
# 不在每次登录时重写：在系统设置里应用 Global Theme 会清掉 kwinrc 的逐组件
# 覆盖（装饰退回主题自带的圆角），直到下一次 rebuild 激活才恢复。
#
# GTK 应用自身的顶层圆角由 pkgs/mactahoe-gtk-theme 压成 0，不走 KWin 装饰，
# 故不在这里处理。niri 不读 kwinrc，继续用 geometry-corner-radius 8 裁角。
{
  lib,
  osConfig,
  pkgs,
  myLib,
  ...
}:
let
  kwriteconfig = "${pkgs.kdePackages.kconfig}/bin/kwriteconfig6";

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

      # 直角窗饰只需要 Aurorae 的 WhiteSur-*-sharp。上游 install.sh 还会安装
      # WhiteSur 的桌面主题、look-and-feel、配色、Kvantum 与壁纸；这些留在
      # Home Manager profile 里会继续出现在 Plasma 系统设置中，故只保留 aurorae。
      if [ -d "$out/share" ]; then
        find "$out/share" -mindepth 1 -maxdepth 1 ! -name aurorae -exec rm -rf {} +
      fi

      runHook postInstall
    '';
  });

  # 仓库声明的 KDE 外观键。只在 rebuild 激活时写一次：
  #   - 装饰：装饰主题被 Global Theme 覆盖后，靠下一次 rebuild 恢复；
  #   - 图标/光标：Plasma 对新启动的应用立即生效，已运行的应用重启后生效。
  # 不放到 plasma-workspace/env：那会在每次登录、KWin 启动前重写一遍。
  applyKdeAppearance = pkgs.writeShellScript "kde-appearance" ''
    ${kwriteconfig} --file "$HOME/.config/kwinrc" \
      --group org.kde.kdecoration2 --key library org.kde.kwin.aurorae.v2
    ${kwriteconfig} --file "$HOME/.config/kwinrc" \
      --group org.kde.kdecoration2 --key theme __aurorae__svg__WhiteSur-dark-sharp
    ${kwriteconfig} --file "$HOME/.config/kdeglobals" \
      --group Icons --key Theme WhiteSur-dark
    ${kwriteconfig} --file "$HOME/.config/kcminputrc" \
      --group Mouse --key cursorTheme ${myLib.theme.cursor}
    ${kwriteconfig} --file "$HOME/.config/kcminputrc" \
      --group Mouse --key cursorSize 24
  '';
in
{
  config = lib.mkIf osConfig.mySystem.desktop.plasma.enable {
    home.packages = [
      whitesurKdeSquare
      # 图标主题要落在 XDG_DATA_DIRS 里 KDE 才能按名找到；GTK 侧由
      # themes/default.nix 的 gtk.iconTheme.package 再装一份（Nix 去重）。
      pkgs.whitesur-icon-theme
    ];

    # 其他键由 KWin/系统设置动态维护，这里只写仓库声明的几个。
    # 写完通知 KWin reconfigure 让装饰立即生效；niri 会话没有 KWin，
    # qdbus 失败可忽略。
    home.activation.kdeAppearance = lib.hm.dag.entryAfter [ "installPackages" ] ''
      $DRY_RUN_CMD ${applyKdeAppearance}
      if [ -n "''${DBUS_SESSION_BUS_ADDRESS:-}" ]; then
        $DRY_RUN_CMD ${pkgs.kdePackages.qttools}/bin/qdbus \
          org.kde.KWin /KWin reconfigure >/dev/null 2>&1 || true
      fi
    '';
  };
}
