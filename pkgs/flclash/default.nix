# flclash —— 基于 ClashMeta 的多平台代理客户端（上游 chen08209/FlClash）
#
# 为什么自己打包：nixpkgs 在 26.05 分支收录过 flclash（0.8.92），2026-08-17 以
# 「用户少 + 无人维护」为由从 master 移除，pkgs/top-level/aliases.nix 里留了
# throw 的墓碑。本仓库的 nixpkgs 输入跟 master，故 `pkgs.flclash` 一度不存在。
# 烂掉的是 nixpkgs 那份打包，不是软件本身——上游活得好好的（v0.9.2 / 2026-10-24，
# 5.9 万 star，GPL-3.0）。
#
# 为什么用上游预编译 deb 而不是源码构建：nixpkgs 那份走
# flutter335.buildFlutterApplication 从源码编，每个上游版本要同步三份钉子——
# pubspec.lock.json、git-hashes.json（flutter 的 git 依赖）、core 的 vendorHash
# （Go 侧）。三份钉子任一没跟上就构建失败，这正是它在 nixpkgs 里停更的原因。
# 上游给每个版本发 linux-{amd64,arm64}.deb 与 SHA256SUMS，故这里只钉版本 +
# 一个哈希，升级只改两行。
#
# 目录布局不能改：上游 lib/common/path.dart 用
#   dirname(Platform.resolvedExecutable) 拼出 FlClashCore 与 FlClashHelperService，
# 即 GUI 与 core 必须在同一目录，且 lib/、data/ 相对该目录（二进制的 RUNPATH 是
# $ORIGIN/lib）。故整包放 $out/libexec/flclash/，$out/bin/FlClash 是 wrapper：
# wrapper 里的 exec 换掉进程映像，/proc/self/exe 于是指向真 ELF，Dart 的
# Platform.resolvedExecutable 才对。若入口直接是软链或解释器，resolvedExecutable
# 会落到它身上，core 就找不到了。
#
# 已知限制（详见 docs/quirks.md）：
#   - TUN 模式依赖 FlClashHelperService 提权（上游 Linux 包装给 setuid root），
#     Nix store 不允许 setuid，故只有「系统代理」模式可用。本仓库客户机的透明
#     转发走 redsocks + mihomo，不依赖 TUN，不受影响。
#   - 与 clash-verge-rev 同为 Clash 内核的 GUI，会抢同一批端口（7890/7897/1053），
#     两者只能同时开一个。2026-10-28 起本仓库的代理客户端已从 clash-verge-rev
#     换成 FlClash：两者端口布局相同（mixed-port 7897、dns listen 0.0.0.0:1053），
#     仓库的 proxy*.nix 不用改。
#
# 升级步骤：
#   1. 改 version；
#   2. 取上游 SHA256SUMS（<release>/SHA256SUMS）里对应 deb 的十六进制哈希，转 SRI：
#      nix hash convert --hash-algo sha256 --to sri <hex>
{
  lib,
  stdenvNoCC,
  fetchurl,
  dpkg,
  autoPatchelfHook,
  makeWrapper,
  makeDesktopItem,
  copyDesktopItems,
  atk,
  cairo,
  fontconfig,
  glib,
  gtk3,
  libX11,
  libayatana-appindicator,
  libepoxy,
  pango,
}:
let
  version = "0.9.2";

  # 上游每个版本只发这两个平台的 deb，资产名见 release 页
  sources = {
    x86_64-linux = {
      asset = "amd64";
      hash = "sha256-xso3RG25K1cwnRxwn7piCfLGebbTPPx0j3O46xpZpug=";
    };
    aarch64-linux = {
      asset = "arm64";
      hash = "sha256-FXAhGSGNKIlDl4YR22dO63SVkR0Hul4URHRDYTU98+Y=";
    };
  };

  source =
    sources.${stdenvNoCC.hostPlatform.system} or (throw ''
      flclash: 上游未发布 ${stdenvNoCC.hostPlatform.system} 的预编译包
      可用平台：linux-x86_64 / linux-aarch64
      见 https://github.com/chen08209/FlClash/releases
    '');
in
stdenvNoCC.mkDerivation {
  pname = "flclash";
  version = version;

  src = fetchurl {
    url = "https://github.com/chen08209/FlClash/releases/download/v${version}/FlClash-${version}-linux-${source.asset}.deb";
    hash = source.hash;
  };

  nativeBuildInputs = [
    dpkg
    autoPatchelfHook
    copyDesktopItems
    makeWrapper
  ];

  # bundle 里直接链接的库（DT_NEEDED），其余靠 autoPatchelf 沿 RUNPATH 递归找
  buildInputs = [
    atk
    cairo
    fontconfig
    glib
    gtk3
    libX11
    libayatana-appindicator
    libepoxy
    pango
  ];

  # 预编译产物：不 configure / 不 build。strip 对 Flutter 的 AOT 快照
  #（libapp.so）没有收益，还会毁掉上游的构建信息。
  dontConfigure = true;
  dontBuild = true;
  dontStrip = true;

  # 上游二进制靠 $ORIGIN/lib 找 Flutter 引擎与插件 .so。nixpkgs 的 autoPatchelf
  # 默认把 RUNPATH 换成绝对 store 路径，那样 $ORIGIN/lib 就没了；--preserve-origin
  # 保留 $ORIGIN 条目（nixpkgs 自己的 pkgs/test/auto-patchelf-hook-preserve-origin
  # 就是这个用例）。
  autoPatchelfFlags = [
    "--preserve-origin"
  ];

  # libdartjni.so 是 JVM 互操作用的（Android 侧），FlClash 走不通它，
  # 且上游没发 JVM。它 NEEDED 的 libjvm.so 找不到，属预期。
  autoPatchelfIgnoreMissingDeps = [
    "libjvm.so"
  ];

  installPhase = ''
    runHook preInstall

    # 解包用 dpkg-deb --fsys-tarfile | tar，而不是 dpkg-deb -x：后者遇到带
    # setuid 位的文件会直接报错（上游哪天给 FlClashHelperService 加 setuid
    # 就炸），--fsys-tarfile 只吐 tar 流，setuid 位由 tar 自己处理。
    # （nixpkgs 的 dpkg 包自带 unpack setup hook，也是这么解的。）
    mkdir -p deb $out/libexec/flclash
    dpkg-deb --fsys-tarfile $src | tar --extract --directory=deb

    cp -r deb/opt/FlClash/. $out/libexec/flclash/

    install -Dm644 deb/usr/share/icons/hicolor/256x256/apps/FlClash.png \
      $out/share/icons/hicolor/256x256/apps/flclash.png

    # wrapper 要在 fixup 阶段之前建好：fixup 的 patchShebangs 会把它的 #! 换成
    # store 里的 bash。wrapper 里的 exec 会换掉进程映像，/proc/self/exe 于是
    # 指向真 ELF，Dart 的 Platform.resolvedExecutable 才对——软链会指错，
    # core 就找不到了（见文件头）。
    makeWrapper $out/libexec/flclash/FlClash $out/bin/FlClash \
      --prefix LD_LIBRARY_PATH : $out/libexec/flclash/lib

    runHook postInstall
  '';

  desktopItems = [
    (makeDesktopItem {
      name = "flclash";
      exec = "FlClash %U";
      icon = "flclash";
      desktopName = "FlClash";
      genericName = "FlClash";
      comment = "Proxy client based on ClashMeta";
      categories = [ "Network" ];
      keywords = [
        "FlClash"
        "Clash"
        "ClashMeta"
        "Proxy"
      ];
      mimeTypes = [
        "x-scheme-handler/clash"
        "x-scheme-handler/clashmeta"
        "x-scheme-handler/flclash"
      ];
      startupNotify = true;
      startupWMClass = "com.follow.clash";
    })
  ];

  meta = {
    description = "Proxy client based on ClashMeta, simple and easy to use";
    homepage = "https://github.com/chen08209/FlClash";
    changelog = "https://github.com/chen08209/FlClash/releases/tag/v${version}";
    license = lib.licenses.gpl3Plus;
    mainProgram = "FlClash";
    platforms = [
      "x86_64-linux"
      "aarch64-linux"
    ];
    sourceProvenance = with lib.sourceTypes; [ binaryNativeCode ];
  };
}
