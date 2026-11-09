# dalibre —— calibre 书库的轻量原生管理器（上游 djyde/dalibre）
#
# nixpkgs 未收录，故自维护。上游是 Go + MyGo 写的单文件原生程序（no webview、
# no cgo），发布预编译 tar.gz，故这里只钉版本 + 一个哈希。
#
# 两处依赖需要显式接线：
#
# 1. 运行时 dlopen 的 GTK 栈。二进制的 DT_NEEDED 只有 libc / libdl / libpthread
#    （purego 通过 dlopen 取其余库），所以 buildInputs 光列库不够 —— 用
#    autoPatchelfHook 的 runtimeDependencies 把它们写进主程序的 RPATH，
#    dlopen 才会沿调用方的 RUNPATH 找到。清单取自实测 strace：
#    gtk3 / gdk-pixbuf / pango / cairo / epoxy / glib / libsecret /
#    appindicator（托盘）/ GL（libglvnd 只给分发器，真驱动来自系统）。
#
# 2. 已知缺件：Glance（书内网页预览）要 WebKitGTK 4.0
#    （libwebkit2gtk-4.0.so.37 + libjavascriptcoregtk-4.0.so.18），nixpkgs 已随
#    libsoup-2.4 一并移除，4.1 的 soname 不同、ABI 不兼容，不能顶替。
#    故该功能不可用（懒加载，不影响其余部分）。
#
# 自更新：上游自带 `mygo` 更新器，安装时会写回**可执行文件所在目录**。装进只读
# 的 /nix/store 后必然失败（与 magpie 同一个坑，见 docs/quirks.md），升级改这里。
#
# 升级步骤：
#   1. 改 version；
#   2. 取上游 SHA256SUMS 里 dalibre-<版本>-linux-<asset>.tar.gz 的十六进制哈希，
#      转 SRI：nix hash convert --hash-algo sha256 --to sri <hex>
{
  lib,
  stdenvNoCC,
  fetchurl,
  autoPatchelfHook,
  makeDesktopItem,
  copyDesktopItems,
  imagemagick,
  gtk3,
  gdk-pixbuf,
  glib,
  pango,
  cairo,
  libepoxy,
  libsecret,
  libappindicator-gtk3,
  at-spi2-core,
  fontconfig,
  freetype,
  libx11,
  libxkbcommon,
  wayland,
  libglvnd,
}:
let
  version = "0.2.2";

  sources = {
    x86_64-linux = {
      asset = "amd64";
      hash = "sha256-fYe4UvstAprasH8nZGMNDULRTjVY6VJXW/yk4IR2zPs=";
    };
    aarch64-linux = {
      asset = "arm64";
      hash = "sha256-9iz4mLDLG2/50g82Xkju9PFluB34xJSieZUuXCy4k0A=";
    };
  };

  source =
    sources.${stdenvNoCC.hostPlatform.system} or (throw ''
      dalibre: 上游未发布 ${stdenvNoCC.hostPlatform.system} 的预编译包
      可用平台：linux-x86_64 / linux-aarch64
      见 https://github.com/djyde/dalibre/releases
    '');

  # dlopen 取用的库：写进 RPATH，dlopen 才能从主程序找到。
  # 一律经 lib.getLib 取库输出 —— glib / pango / fontconfig 默认的 out 是
  # 空壳，库在 lib 输出里，直接写包名会得到 ...-glib-2.88.3-bin/lib 这种
  # 不含 .so 的路径（实测 dlopen 失败：libgobject-2.0.so.0 打不开）。
  runtimeLibs = map lib.getLib [
    gtk3
    gdk-pixbuf
    glib
    pango
    cairo
    libepoxy
    libsecret
    libappindicator-gtk3
    at-spi2-core
    fontconfig
    freetype
    libx11
    libxkbcommon
    wayland
    libglvnd
  ];
in
stdenvNoCC.mkDerivation {
  pname = "dalibre";
  inherit version;

  src = fetchurl {
    url = "https://github.com/djyde/dalibre/releases/download/v${version}/dalibre-${version}-linux-${source.asset}.tar.gz";
    hash = source.hash;
  };

  nativeBuildInputs = [
    autoPatchelfHook
    copyDesktopItems
    imagemagick
  ];

  # DT_NEEDED 里只有 libc/libdl/libpthread，autoPatchelf 补它们
  buildInputs = [ glib ];

  # dlopen 的库不在 DT_NEEDED 里，靠 runtimeDependencies 写进 RPATH
  runtimeDependencies = runtimeLibs;

  # 上游 tar.gz 没有顶层目录（dalibre / dalibre.desktop / *.png 平铺），
  # 不设 sourceRoot 时 unpackPhase 会报 "produced no directories"。
  sourceRoot = ".";

  # 预编译产物：不 configure / 不 build。Go 二进制 strip 无收益，
  # 且会抹掉上游的构建信息。
  dontConfigure = true;
  dontBuild = true;
  dontStrip = true;

  installPhase = ''
    runHook preInstall

    install -Dm755 dalibre $out/bin/dalibre

    # 上游只给一张 1024x1024 的 PNG。**不能只装 1024x1024**：hicolor 的
    # index.theme（GNOME themes-extra 提供）没有列出 1024x1024 目录，GTK 按
    # index 的子目录清单查找，因此根本不会去扫这个目录，图标表现为「不存在」。
    # 故按 index.theme 列出的标准尺寸逐级缩放，应用启动器/任务栏才找得到。
    # 1024x1024 仍保留一份（部分直接扫目录的工具会用到）。
    for size in 16 24 32 48 64 96 128 192 256 512; do
      mkdir -p "$out/share/icons/hicolor/''${size}x''${size}/apps"
      magick dalibre.png -resize "''${size}x''${size}" \
        "$out/share/icons/hicolor/''${size}x''${size}/apps/dalibre.png"
    done
    install -Dm644 dalibre.png $out/share/icons/hicolor/1024x1024/apps/dalibre.png

    runHook postInstall
  '';

  desktopItems = [
    (makeDesktopItem {
      name = "dalibre";
      exec = "dalibre %U";
      icon = "dalibre";
      desktopName = "Dalibre";
      genericName = "E-book Library Manager";
      comment = "Read and write calibre libraries";
      categories = [
        "Office"
        "Utility"
      ];
      keywords = [
        "ebook"
        "calibre"
        "library"
      ];
      mimeTypes = [
        "application/epub+zip"
        "application/x-mobipocket-ebook"
      ];
      startupNotify = true;
      startupWMClass = "dalibre";
    })
  ];

  meta = {
    description = "Native e-book library manager for calibre libraries";
    homepage = "https://dalibre.randynamic.org/";
    changelog = "https://github.com/djyde/dalibre/releases/tag/v${version}";
    # 上游仓库没有 LICENSE 文件，按未授权处理
    license = lib.licenses.unfree;
    mainProgram = "dalibre";
    platforms = [
      "x86_64-linux"
      "aarch64-linux"
    ];
    sourceProvenance = with lib.sourceTypes; [ binaryNativeCode ];
  };
}
