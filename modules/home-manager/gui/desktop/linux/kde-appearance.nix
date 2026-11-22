# KDE 外观（仓库声明部分）
#
# 全部外观取自 WhiteSur-kde 的浅色变体（上游 KDE 侧名不带 -light 后缀；只有
# GTK 叫 WhiteSur-Light）。窗饰为圆角 opaque，按钮布局在右侧。面板布局与字体
# 仍归系统设置；这里声明 WhiteSur 外观的各个面，因为它们在系统设置里没有稳定
# 的「一次配置」入口，或在应用 Global Theme 后会被覆盖：
#   - 窗口外角：KWin 服务端装饰（KDE/Qt 窗口）走上游圆角 WhiteSur-opaque
#   - 窗口按钮：右侧 IAX（最小化/最大化/关闭），左侧留空
#   - 配色方案：WhiteSur（整份 [Colors:*] 写入 kdeglobals）
#   - Plasma 桌面主题：WhiteSur（面板、弹窗、小组件）
#   - 应用风格：Kvantum + WhiteSur 主题（上游的 kvantum 键）
#   - 图标主题：WhiteSur-light（与 GTK 侧同款，见 themes/variants.nix）
#   - 启动画面：WhiteSur（系统级包 whitesur-plasma-splash）
#   - 注销界面：WhiteSur（本模块在用户级构造 shell 包副本）
#   - 光标主题：Bibata-Modern-Ice，24 逻辑像素（与 GTK/SDDM/niri 同款，
#     名字来自 lib/default.nix 的 myLib.theme.cursor）
#
# 快速平铺间距见同目录 kwin-tile-gaps.nix（KWin 6.8 把 quick tile padding
# 固定为 0，需要脚本补 8px）。
#
# 写入方式：rebuild 激活时用 kwriteconfig6 **逐键**写入 kwinrc / kdeglobals /
# kcminputrc / ksplashrc —— 这些文件的其他键由 KDE 运行时持续维护，不能整文件
# 托管。不在每次登录时重写：在系统设置里应用 Global Theme 会清掉 kwinrc 的逐组件
# 覆盖，直到下一次 rebuild 激活才恢复。
#
# GTK 应用自身的圆角由 WhiteSur-GTK 决定，不走 KWin 装饰；niri 不读 kwinrc，
# 继续用 geometry-corner-radius 8 裁角。
{
  lib,
  osConfig,
  pkgs,
  myLib,
  ...
}:
let
  kwriteconfig = "${pkgs.kdePackages.kconfig}/bin/kwriteconfig6";
  # 配色与桌面主题用 Plasma 官方 CLI：配色必须整份写入 [Colors:*]，
  # 只改 ColorScheme 名字时旧色值仍留在 kdeglobals 里（实测）。
  plasmaApplyColorScheme = "${pkgs.kdePackages.plasma-workspace}/bin/plasma-apply-colorscheme";
  plasmaApplyDesktopTheme = "${pkgs.kdePackages.plasma-workspace}/bin/plasma-apply-desktoptheme";

  # nixpkgs 的 whitesur-kde 安装全部变体。这里复用同一份上游源码和 postPatch，
  # 只保留仓库实际声明的面，避免系统设置里出现「另一套 WhiteSur」（浅色/alt/
  # sharp/opaque）与声明的外观分叉。
  #
  # Splash 由系统级包 whitesur-plasma-splash 提供，SDDM 主题由
  # whitesur-sddm-theme 提供，注销界面由下面构造的用户级 shell 包提供；故这里
  # 裁掉 look-and-feel 与 sddm。
  whitesurKde = pkgs.whitesur-kde.overrideAttrs (old: {
    pname = "whitesur-kde-plasma";

    installPhase = ''
      runHook preInstall

      mkdir -p $out/doc
      name= ./install.sh --window opaque

      # 只保留 aurorae（圆角 opaque 窗饰）、color-schemes（WhiteSur）、
      # plasma/desktoptheme（WhiteSur）与 Kvantum（WhiteSur 应用风格）。
      if [ -d "$out/share" ]; then
        find "$out/share" -mindepth 1 -maxdepth 1 \
          ! -name aurorae ! -name color-schemes ! -name plasma ! -name Kvantum \
          -exec rm -rf {} +
        rm -rf "$out/share/plasma/look-and-feel"

        # 每个面只留仓库声明的变体。aurorae 保留 WhiteSur-opaque
        # 及其 DPI 变体。Kvantum 例外：主题名 WhiteSur 需要同目录的
        # WhiteSur.kvconfig 作浅色入口，深色 QPalette 仍会命中
        # WhiteSurDark.kvconfig，故整个目录保留；--window opaque 额外装出的
        # WhiteSur-opaque 应用风格不属于声明面，删掉。
        find "$out/share/aurorae/themes" -mindepth 1 -maxdepth 1 \
          ! -name 'WhiteSur-opaque*' -exec rm -rf {} +
        rm -rf "$out/share/Kvantum/WhiteSur-opaque"
        find "$out/share/color-schemes" -mindepth 1 -maxdepth 1 \
          ! -name WhiteSur.colors -exec rm -rf {} +
        find "$out/share/plasma/desktoptheme" -mindepth 1 -maxdepth 1 \
          ! -name WhiteSur -exec rm -rf {} +
      fi

      runHook postInstall
    '';
  });

  # Plasma 6.8 的 logout-greeter 读 Plasma/Shell 包（默认
  # org.kde.plasma.desktop），而不是 Global Theme 的 LookAndFeel 包；上游
  # WhiteSur 的 Logout.qml 放在 LookAndFeel 的 contents/logout 下，直接装
  # LookAndFeel 不会生效。这里复制一份 plasma-desktop 的完整 shell 包，把
  # logout 换成 WhiteSur 的，再作为用户级同名包软链到 ~/.local/share。
  #
  # 为什么放用户级而不是往系统 profile 里塞一个同名包：systemPackages 的
  # buildEnv 遇到同名文件只保留一个（ignoreCollisions），胜负依赖包顺序；
  # 用户级完整副本没有碰撞，也不会遮蔽掉 shell 包的 main.js/defaults。
  plasmaShell = pkgs.runCommand "plasma-shell-whitesur" { } ''
    mkdir -p $out
    cp -r ${pkgs.kdePackages.plasma-desktop}/share/plasma/shells/org.kde.plasma.desktop/. $out/
    # store 里的文件是只读的，覆盖 logout 前先给副本加写权限。
    chmod -R u+w $out/contents/logout
    cp -r ${pkgs.whitesur-kde.src}/plasma/look-and-feel/com.github.vinceliuice.WhiteSur/contents/logout/. $out/contents/logout/
  '';

  # 仓库声明的 KDE 外观键。只在 rebuild 激活时写一次：
  #   - 装饰/配色/桌面主题/启动画面：被 Global Theme 覆盖后，靠下一次 rebuild 恢复；
  #   - 图标/光标/应用风格：Plasma 对新启动的应用立即生效，已运行的应用重启后生效。
  # 不放到 plasma-workspace/env：那会在每次登录、KWin 启动前重写一遍。
  applyKdeAppearance = pkgs.writeShellScript "kde-appearance" ''
    # 激活环境里不保证有 HM profile 的 share；补上本包，CLI 才能找到
    # WhiteSur.colors 与 WhiteSur 桌面主题。
    export XDG_DATA_DIRS="${whitesurKde}/share''${XDG_DATA_DIRS:+:$XDG_DATA_DIRS}"
    # plasma-apply-* 是 QGuiApplication，激活时通常没有显示服务器；
    # offscreen 平台插件让它们只写配置，DBus 仍照常通知运行中的 Plasma。
    export QT_QPA_PLATFORM=offscreen

    # 窗饰与按钮：上游 WhiteSur-opaque 的圆角变体，按钮在右（IAX）。
    ${kwriteconfig} --file "$HOME/.config/kwinrc" \
      --group org.kde.kdecoration2 --key library org.kde.kwin.aurorae
    ${kwriteconfig} --file "$HOME/.config/kwinrc" \
      --group org.kde.kdecoration2 --key theme __aurorae__svg__WhiteSur-opaque
    ${kwriteconfig} --file "$HOME/.config/kwinrc" \
      --group org.kde.kdecoration2 --key ButtonsOnLeft ""
    ${kwriteconfig} --file "$HOME/.config/kwinrc" \
      --group org.kde.kdecoration2 --key ButtonsOnRight IAX
    ${kwriteconfig} --file "$HOME/.config/kdeglobals" \
      --group Icons --key Theme WhiteSur-light
    # 上游用 kvantum 这个 style key；Kvantum 的 kvconfig 主题名仍是
    # WhiteSur（WhiteSur.kvconfig 是浅色档，WhiteSurDark.kvconfig 是深色档）。
    ${kwriteconfig} --file "$HOME/.config/kdeglobals" \
      --group KDE --key widgetStyle kvantum
    ${kwriteconfig} --file "$HOME/.config/kcminputrc" \
      --group Mouse --key cursorTheme ${myLib.theme.cursor}
    ${kwriteconfig} --file "$HOME/.config/kcminputrc" \
      --group Mouse --key cursorSize 24

    # 启动画面：ksplashqml 按 ksplashrc 的 Theme 找 LookAndFeel 包
    # （内容由系统级 whitesur-plasma-splash 装进 system profile）。
    ${kwriteconfig} --file "$HOME/.config/ksplashrc" \
      --group KSplash --key Engine KSplashQML
    ${kwriteconfig} --file "$HOME/.config/ksplashrc" \
      --group KSplash --key Theme com.github.vinceliuice.WhiteSur

    ${plasmaApplyColorScheme} WhiteSur \
      || echo "kde-appearance: WhiteSur 配色应用失败" >&2
    ${plasmaApplyDesktopTheme} WhiteSur \
      || echo "kde-appearance: WhiteSur 桌面主题应用失败" >&2
  '';
in
{
  config = lib.mkIf osConfig.mySystem.desktop.plasma.enable {
    home.packages = [
      whitesurKde
      # 图标主题要落在 XDG_DATA_DIRS 里 KDE 才能按名找到；GTK 侧由
      # themes/default.nix 的 gtk.iconTheme.package 再装一份（Nix 去重）。
      pkgs.whitesur-icon-theme
      # Kvantum 样式插件：qt.kvantum.enable 只写 kvconfig，不装插件（插件随
      # qt.style.name 走，而那个选项会全局导出 QT_STYLE_OVERRIDE，见 quirk）。
      # Qt5 一并装上，Plasma 会话里的 Qt5 应用也按 widgetStyle 走 Kvantum。
      pkgs.kdePackages.qtstyleplugin-kvantum
      pkgs.libsForQt5.qtstyleplugin-kvantum
    ];

    # 用户级同名 shell 包：logout-greeter 与 plasmashell 都优先读
    # $XDG_DATA_HOME，内容来自 plasma-desktop 的完整副本 + WhiteSur logout。
    # 用目录软链（recursive = false），不展开成 HM 的逐文件软链。
    xdg.dataFile."plasma/shells/org.kde.plasma.desktop" = {
      source = plasmaShell;
      recursive = false;
    };

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
