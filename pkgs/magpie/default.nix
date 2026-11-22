# magpie —— 把本机各 AI agent 的模型选择收在一处的工具（上游 yetone/magpie）
#
# nixpkgs 未收录，故自维护。上游是单个 Go 程序，界面是手写 HTML，没有前端构建
# 步骤，buildGoModule 直接可编。同一份源码与 vendor 出两个产物（gui 参数）：
#   - gui = true：桌面版，经 cgo 链接系统 webview（Linux 下 GTK3 + WebKitGTK 4.1），
#     闭包约 970 MiB，故只给有图形会话的主机（desktop/laptop，见 gui 层 apps/utilities）
#   - gui = false：纯终端版，即上游 `make cli` 的形态（nogui tag + CGO_ENABLED=0，
#     无 cgo 依赖），无图形会话的主机用这份（wsl，见 hosts/wsl/default.nix）
# 上游 Makefile 在 Linux 上主动加 gtk3 tag：Wails 默认走 GTK4 + WebKitGTK 6，
# 该 tag 是为兼容老发行版。本包的 nixpkgs 两个 WebKitGTK 版本都有，这里沿用
# gtk3 与上游 release-linux 保持一致（ldd 落在 gtk+3 / webkitgtk+abi=4.1）。
#
# GUI 版还须带 gst-plugins-good：WebKitGTK 给每个 <video>（静音的也算）建
# audio sink —— MediaPlayerPrivateGStreamer::createAudioSink 用 autoaudiosink，
# 它在 gst-plugins-good 的 libgstautodetect.so 里。插件目录不在环境里就创建
# 失败，WebKit 直接 RELEASE_ASSERT abort（WebKitWebProcess SIGABRT，窗口留白）。
# nixpkgs 的 Tauri 应用由 cargo-tauri hook 自动写 GST_PLUGIN_SYSTEM_PATH_1_0，
# Wails 没有对应 hook；又不能包一层 shell wrapper —— 那会改掉 os.Executable()，
# 破坏 magpie 往 ~/.local/share/applications/magpie.desktop 写 magpie:// 条目
# 的判定（它把绝对值 exe 路径钉进 Exec=）。所以改为在 Go 的 package main 里
# 注入一个 init：启动时把本包闭包内的插件目录补进环境，Wails 之后拉起的
# WebKitWebProcess 会继承。只带 core + base + good 就够本仓库的用途
# （WebM 的 matroska/vpx/vorbis/opus 与 autoaudiosink 都在其中）；-bad 会多
# 背约 290 MiB，只为 fakeaudiosink 兜底，不值得。
#
# metadata.platforms 只声明 linux：终端版在 darwin 上理论可编，但本机没有 darwin
# 构建器可验证，先不给 macbook 装机（要装另说）。
#
# doCheck = false：上游 internal/proc 的测试扫描源码树里的 os/exec 调用，而 nix
# 的 vendoring 把依赖铺进 vendor/，扫描必然命中 vendor 内的第三方代码，测试在
# nix 下必挂（不是本包配置问题，也不是真实回归）。
#
# 升级不走 `magpie update`（自带的后台自更新会替换自己的二进制，store 只读，
# 必然失败），改的是这个文件：
#   1. 改 version；
#   2. src.hash 先填 lib.fakeHash 跑一次，取报错里的 got:；
#   3. vendorHash 同理，仅在 go.mod/go.sum 有变化时才需要变。
{
  lib,
  buildGoModule,
  fetchFromGitHub,
  pkg-config,
  gtk3,
  webkitgtk_4_1,
  gst_all_1,
  gui ? true,
}:

let
  # GUI 版要把 GStreamer 插件带进闭包，并在启动时写进环境（原因见文件头）。
  # 用 lib.getLib 取 out 输出：gstreamer 的默认输出是 bin，里面没有插件。
  gstPlugins = with gst_all_1; [
    gstreamer
    gst-plugins-base
    gst-plugins-good
  ];
  gstPluginPath = lib.makeSearchPath "lib/gstreamer-1.0" (map lib.getLib gstPlugins);
in
buildGoModule rec {
  pname = if gui then "magpie" else "magpie-cli";
  version = "0.1.4667";

  src = fetchFromGitHub {
    owner = "yetone";
    repo = "magpie";
    rev = "v${version}";
    hash = "sha256-qc1pPMiVA1IZDdRFK0i4mfMEX1Gm+CTD72VsSiPIzaI=";
  };

  vendorHash = "sha256-Adyhp/oY0nWiSXOwrsbHTEFp60H9aJWUoPKUUUrYItc=";

  tags =
    if gui then
      [
        "production"
        "gtk3"
      ]
    else
      [ "nogui" ];

  # 只编主包（上游 `go build .` 同义）：buildGoModule 默认会把模块内每个含
  # .go 的目录都编一遍，而 internal/gui 无条件 import Wails，在 nogui + 无 cgo
  # 的终端版下必然报 undefined（它本就不该被编译）。
  subPackages = [ "." ];

  ldflags = [
    "-s"
    "-w"
    "-X main.version=${version}"
  ]
  ++ lib.optional gui "-X main.nixGstPluginPath=${gstPluginPath}";

  # Wails 的 Linux 后端在编译期用 pkg-config 探 gtk/webkit
  nativeBuildInputs = lib.optional gui pkg-config;

  buildInputs = lib.optionals gui (
    [
      gtk3
      webkitgtk_4_1
    ]
    ++ map lib.getLib gstPlugins
  );

  env.CGO_ENABLED = if gui then 1 else 0;

  # 见文件头：Wails 没有 Tauri 那种 GST 插件路径 hook，shell wrapper 又会改掉
  # os.Executable()，故在 package main 里加一个 init 补环境变量。GST 路径用
  # ldflags 注入（-X），插件目录因此稳定留在闭包里。
  postPatch = lib.optionalString gui ''
    cat > nixgst.go <<'GO'
    package main

    import "os"

    // nixGstPluginPath is this build's GStreamer plugin directories, set with
    // -ldflags -X from pkgs/magpie/default.nix. WebKitGTK aborts the web
    // process when it cannot find autoaudiosink (gst-plugins-good), and Wails
    // brings no plugin path of its own.
    var nixGstPluginPath = ""

    func init() {
    	if nixGstPluginPath == "" {
    		return
    	}
    	if old := os.Getenv("GST_PLUGIN_SYSTEM_PATH_1_0"); old != "" {
    		nixGstPluginPath += ":" + old
    	}
    	os.Setenv("GST_PLUGIN_SYSTEM_PATH_1_0", nixGstPluginPath)
    }
    GO
  '';

  # 上游不安装任何图标：它自己写的桌面文件（internal/gui/scheme_linux.go，用于
  # 抢占 magpie:// 协议）里 Icon=magpie 指向一个从不存在的图标名，应用启动器
  # （Noctalia / GNOME 等）匹配不到就回退成通用齿轮图标。上游仓库自带
  # build/icon/magpie.svg，按 hicolor 规范装进 scalable/apps，图标名即 "magpie"。
  # 终端版没有桌面文件，不需要。
  postInstall = lib.optionalString gui ''
    install -Dm644 $src/build/icon/magpie.svg \
      $out/share/icons/hicolor/scalable/apps/magpie.svg
  '';

  doCheck = false;

  meta = {
    description = "One place to pick every AI agent's model";
    homepage = "https://github.com/yetone/magpie";
    changelog = "https://github.com/yetone/magpie/releases/tag/v${version}";
    license = lib.licenses.mit;
    mainProgram = "magpie";
    platforms = lib.platforms.linux;
  };
}
