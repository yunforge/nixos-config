# misterdownloadmanager —— 用 Rust 从零重写的下载管理器（上游 anefzaoui/misterdownloadmanager）
#
# nixpkgs 未收录，故自维护。上游是纯 Rust（egui）原生程序，每个版本发预编译
# deb / rpm / AppImage / tar.gz，这里取 deb（唯一同时带桌面条目、图标、扩展与
# 四个可执行文件的资产），升级只改版本 + 一个哈希。
#
# 四个可执行文件必须留在同一个目录（$out/bin）：
#   misterdownloadmanager         GUI
#   misterdownloadmanager-cli     命令行
#   misterdownloadmanager-mcp     MCP server
#   misterdownloadmanager-nmhost  浏览器 Native Messaging Host
# 浏览器集成由 MDM 在每次启动时自己完成（往各浏览器的 NativeMessagingHosts
# 目录写 manifest），它用 `current_exe().with_file_name("misterdownloadmanager-nmhost")`
# 找 helper（crates/app/src/unix.rs 的 host_program）。所以 nmhost **不能**挪到
# libexec——挪了浏览器扩展就连不上。
#
# 运行时依赖：主二进制的 DT_NEEDED 只有 libgcc_s / libm / libc，X11 / Wayland /
# GL / Vulkan / D-Bus 全走 dlopen（winit、glutin、ash 的 -dl 绑定）。故用
# autoPatchelf 的 runtimeDependencies 把库写进 RPATH（与 dalibre / pulse 同一做法，
# 清单取自二进制里 dlopen 的 soname）：
#   X11: libX11 / libX11-xcb / libxcb / libXi / libXrender / libXcursor
#   输入: libxkbcommon（含 -x11）/ wayland（client + egl）
#   GL: libglvnd（libGL/libEGL）；Vulkan 可选项见「View → Draw with → Vulkan」
#   D-Bus: libdbus-1
#
# 已知限制（Nix store 只读，详见 docs/quirks.md）：
#   - 应用内「检查更新」会把新版本写回可执行文件所在目录，必然失败；升级改这里。
#   - 应用内「登录时启动」把**绝对 store 路径**写进 ~/.config/autostart/，
#     升级被 GC 后开机不起（与 magpie / dalibre 同一个坑）。不要用它，需要自启
#     时由 HM 声明 autostart 条目（Exec 用命令名走 PATH）。
#
# 升级步骤：
#   1. 改 version；
#   2. 取上游 SHA256SUMS.txt 里 MisterDownloadManager-<版本>-linux-x86_64.deb
#      的十六进制哈希，转 SRI：nix hash convert --hash-algo sha256 --to sri <hex>
#   3. 上游目前只发 x86_64-linux 的 Linux 资产；新增平台时补 sources 条目。
{
  lib,
  stdenv,
  fetchurl,
  dpkg,
  autoPatchelfHook,
  libx11,
  libxcb,
  libxi,
  libxrender,
  libxcursor,
  libxkbcommon,
  wayland,
  libglvnd,
  vulkan-loader,
  dbus,
}:
let
  version = "0.5.2";

  # 上游只发 x86_64-linux 的 deb（rpm / AppImage / tar.gz 同平台）
  sources = {
    x86_64-linux = {
      asset = "x86_64";
      hash = "sha256-nTMNloSggZzqmHyudgGxxQePx3Uglepuay8v7wNakuE=";
    };
  };

  source =
    sources.${stdenv.hostPlatform.system} or (throw ''
      misterdownloadmanager: 上游未发布 ${stdenv.hostPlatform.system} 的预编译包
      可用平台：x86_64-linux
      见 https://github.com/anefzaoui/misterdownloadmanager/releases
    '');

  # dlopen 取用的库：写进 RPATH，dlopen 才能从主程序找到。
  # 一律经 lib.getLib 取库输出（dbus 的库在 lib 输出，默认 out 是空壳）；
  # 其余包没有独立 lib 输出时 getLib 回退到 out。
  runtimeLibs = map lib.getLib [
    libx11
    libxcb
    libxi
    libxrender
    libxcursor
    libxkbcommon
    wayland
    libglvnd
    vulkan-loader
    dbus
  ];
in
stdenv.mkDerivation {
  pname = "misterdownloadmanager";
  inherit version;

  src = fetchurl {
    url = "https://github.com/anefzaoui/misterdownloadmanager/releases/download/v${version}/MisterDownloadManager-${version}-linux-${source.asset}.deb";
    hash = source.hash;
  };

  nativeBuildInputs = [
    dpkg
    autoPatchelfHook
  ];

  # DT_NEEDED 里的 libgcc_s 由 gcc 运行时提供；autoPatchelf 补 libc/libm
  buildInputs = [ stdenv.cc.cc.lib ];

  # dlopen 的库不在 DT_NEEDED 里，靠 runtimeDependencies 写进 RPATH
  runtimeDependencies = runtimeLibs;

  # 预编译产物：不 configure / 不 build；strip 会抹掉上游构建信息
  dontConfigure = true;
  dontBuild = true;
  dontStrip = true;

  installPhase = ''
    runHook preInstall

    # 用 dpkg-deb --fsys-tarfile 而不是 -x：与 flclash 同一个理由，
    # 上游哪天给 helper 加 setuid 位时不会报错。
    mkdir -p deb
    dpkg-deb --fsys-tarfile $src | tar --extract --directory=deb

    # 四个可执行文件必须同目录（nmhost 由 GUI 按 current_exe 的同级路径查找）
    for bin in \
      misterdownloadmanager \
      misterdownloadmanager-cli \
      misterdownloadmanager-mcp \
      misterdownloadmanager-nmhost
    do
      install -Dm755 "deb/usr/bin/$bin" "$out/bin/$bin"
    done

    install -Dm644 deb/usr/share/applications/misterdownloadmanager.desktop \
      $out/share/applications/misterdownloadmanager.desktop
    install -Dm644 deb/usr/share/icons/hicolor/256x256/apps/misterdownloadmanager.png \
      $out/share/icons/hicolor/256x256/apps/misterdownloadmanager.png

    # 浏览器扩展的离线副本（应用内的「添加扩展」按钮走商店，这两份供手动安装）
    cp -r deb/usr/share/misterdownloadmanager $out/share/misterdownloadmanager

    runHook postInstall
  '';

  meta = {
    description = "Download manager with browser integration, written in Rust";
    homepage = "https://misterdownloadmanager.com";
    changelog = "https://github.com/anefzaoui/misterdownloadmanager/releases/tag/v${version}";
    license = lib.licenses.gpl3Plus;
    mainProgram = "misterdownloadmanager";
    platforms = [
      "x86_64-linux"
    ];
    sourceProvenance = with lib.sourceTypes; [ binaryNativeCode ];
  };
}
