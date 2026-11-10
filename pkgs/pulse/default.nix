# pulse —— 系统活动监视器（上游 egoist/pulse-feedback）
#
# nixpkgs 未收录，故自维护。上游是 Go + MyGo 写的单文件原生程序（主界面是
# 原生 GTK3 控件、不是 webview），发布预编译 tar.gz，故这里只钉版本 + 一个哈希。
#
# 两处依赖需要显式接线（与 pkgs/dalibre 同一套做法）：
#
# 1. 运行时 dlopen 的 GTK 栈。二进制的 DT_NEEDED 只有 libc / libdl / libpthread
#    （purego 通过 dlopen 取其余库），所以 buildInputs 光列库不够 —— 用
#    autoPatchelfHook 的 runtimeDependencies 把它们写进主程序的 RPATH，
#    dlopen 才会沿调用方的 RUNPATH 找到。清单取自 mygo 源码
#    internal/linux/ffi.go 的 load()/loadWebKit() 与实测：
#    glib / gobject / gio / gdk-3 / gtk-3 / cairo / gdk-pixbuf（必需）；
#    pango + harfbuzz + fontconfig + freetype（字体渲染，mygo 用 PangoFT2）；
#    libsecret（凭据）、libepoxy（GL）、libX11 / libxkbcommon / wayland（输入与
#    会话）、gtk-layer-shell（面板贴边，Niri 支持 wlr-layer-shell）、
#    ayatana-appindicator + dbusmenu（托盘图标，菜单栏 CPU/内存/网络/温度）、
#    at-spi2-core（无障碍）、libglvnd（GL 分发器，真驱动来自系统）。
#
# 2. WebKitGTK 4.1：只在「关于 / 更新说明」这类内嵌网页里用（mygo 的
#    ui.Content，懒加载），缺了只影响该页，主界面是原生 GTK。这里仍然接上 ——
#    desktop/laptop 的 magpie 已经带着同一份 webkitgtk 4.1 进闭包，实际不增加
#    下载量。4.0 已被 nixpkgs 移除（见 docs/quirks.md），mygo 会先试 4.1。
#
# 自更新：上游自带 `mygo` 更新器（每 5 秒轮询 update-linux-<arch>.json），
# 装进只读的 /nix/store 后无法替换自身（与 magpie / dalibre 同一个坑，见
# docs/quirks.md），升级改这里。
#
# 升级步骤：
#   1. 改 version；
#   2. 取两个平台的哈希：
#      nix store prefetch-file --json \
#        https://github.com/egoist/pulse-feedback/releases/download/v<版本>/pulse-<版本>-linux-amd64.tar.gz \
#        | jq -r .hash
#      （arm64 同理，把 amd64 换成 arm64）
{
  lib,
  stdenvNoCC,
  fetchurl,
  autoPatchelfHook,
  # 必须用 patchelfUnstable（0.19.x）：nixpkgs 默认的 0.15.2 改写这个 Go 二进制
  # 的程序头时会把 PHDR 挤出第一个 PT_LOAD，内核/ld.so 在 dl_main 里直接段错误
  # （`readelf -l` 可见 program headers 从 10 个掉到 9 个）。见 docs/quirks.md。
  patchelfUnstable,
  makeDesktopItem,
  copyDesktopItems,
  imagemagick,
  gtk3,
  gdk-pixbuf,
  glib,
  cairo,
  pango,
  harfbuzz,
  fontconfig,
  freetype,
  libsecret,
  libepoxy,
  libx11,
  libxkbcommon,
  wayland,
  gtk-layer-shell,
  libayatana-appindicator,
  libdbusmenu-gtk3,
  at-spi2-core,
  libglvnd,
  webkitgtk_4_1,
  libsoup_3,
}:
let
  version = "0.1.29";

  sources = {
    x86_64-linux = {
      asset = "amd64";
      hash = "sha256-olXmMKeRMUP7MYTJXER0YF4jj3NAvla33ZA4kcFzcE0=";
    };
    aarch64-linux = {
      asset = "arm64";
      hash = "sha256-hRjnwe2w83maDrqUWVATvoFE4iXD6/x+BtzC4j2OSWQ=";
    };
  };

  source =
    sources.${stdenvNoCC.hostPlatform.system} or (throw ''
      pulse: 上游未发布 ${stdenvNoCC.hostPlatform.system} 的预编译包
      可用平台：linux-amd64 / linux-arm64
      见 https://github.com/egoist/pulse-feedback/releases
    '');

  # dlopen 取用的库：写进 RPATH，dlopen 才能从主程序找到。
  # 一律经 lib.getLib 取库输出 —— glib / pango / fontconfig / gdk-pixbuf 默认的
  # out 是空壳（或 bin），库在 lib 输出里，直接写包名会得到不含 .so 的路径
  # （dalibre 打包时实测过 dlopen 失败）。
  runtimeLibs = map lib.getLib [
    gtk3
    gdk-pixbuf
    glib
    cairo
    pango
    harfbuzz
    fontconfig
    freetype
    libsecret
    libepoxy
    libx11
    libxkbcommon
    wayland
    gtk-layer-shell
    libayatana-appindicator
    libdbusmenu-gtk3
    at-spi2-core
    libglvnd
    webkitgtk_4_1
    libsoup_3
  ];
in
stdenvNoCC.mkDerivation {
  pname = "pulse";
  inherit version;

  src = fetchurl {
    url = "https://github.com/egoist/pulse-feedback/releases/download/v${version}/pulse-${version}-linux-${source.asset}.tar.gz";
    hash = source.hash;
  };

  nativeBuildInputs = [
    autoPatchelfHook
    # 放在 hook 之后即可：它把 $out/bin 里的 patchelf 覆盖成 0.19.2，
    # auto-patchelf 执行时取到的是这一份。
    patchelfUnstable
    copyDesktopItems
    imagemagick
  ];

  # DT_NEEDED 里只有 libc/libdl/libpthread，autoPatchelf 补它们
  buildInputs = [ glib ];

  # dlopen 的库不在 DT_NEEDED 里，靠 runtimeDependencies 写进 RPATH
  runtimeDependencies = runtimeLibs;

  # 上游 tar.gz 没有顶层目录（pulse / pulse.desktop / *.png 平铺），
  # 不设 sourceRoot 时 unpackPhase 会报 "produced no directories"。
  sourceRoot = ".";

  # 预编译产物：不 configure / 不 build。Go 二进制 strip 无收益，
  # 且会抹掉上游的构建信息。
  dontConfigure = true;
  dontBuild = true;
  dontStrip = true;

  installPhase = ''
    runHook preInstall

    install -Dm755 pulse $out/bin/pulse

    # 上游只给一张 1024x1024 的 PNG。**不能只装 1024x1024**：hicolor 的
    # index.theme（GNOME themes-extra 提供）没有列出 1024x1024 目录，GTK 按
    # index 的子目录清单查找，因此根本不会去扫这个目录，图标表现为「不存在」。
    # 故按 index.theme 列出的标准尺寸逐级缩放，应用启动器/任务栏才找得到。
    # 1024x1024 仍保留一份（部分直接扫目录的工具会用到）。
    for size in 16 24 32 48 64 96 128 192 256 512; do
      mkdir -p "$out/share/icons/hicolor/''${size}x''${size}/apps"
      magick pulse.png -resize "''${size}x''${size}" \
        "$out/share/icons/hicolor/''${size}x''${size}/apps/pulse.png"
    done
    install -Dm644 pulse.png $out/share/icons/hicolor/1024x1024/apps/pulse.png

    runHook postInstall
  '';

  desktopItems = [
    (makeDesktopItem {
      name = "pulse";
      exec = "pulse";
      icon = "pulse";
      desktopName = "Pulse";
      genericName = "Activity Monitor";
      comment = "Everything your computer is doing, in one calm window";
      categories = [
        "System"
        "Monitor"
        "Utility"
      ];
      keywords = [
        "system monitor"
        "processes"
        "cpu"
        "memory"
        "network"
        "activity"
      ];
      startupNotify = true;
      # 实测 WM_CLASS / niri app-id 都是 pulse（mygo 用程序名设 application name）
      startupWMClass = "pulse";
    })
  ];

  meta = {
    description = "Native system activity monitor: processes, CPU, memory, GPU, disk, network, energy";
    homepage = "https://pulse.egoist.dev/";
    changelog = "https://github.com/egoist/pulse-feedback/releases/tag/v${version}";
    # 上游只有反馈仓库（无 LICENSE 文件），按未授权处理
    license = lib.licenses.unfree;
    mainProgram = "pulse";
    platforms = [
      "x86_64-linux"
      "aarch64-linux"
    ];
    sourceProvenance = with lib.sourceTypes; [ binaryNativeCode ];
  };
}
