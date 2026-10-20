# babry —— 懂边界的 Wayland 截图工具（上游 kregonia/babry）
#
# nixpkgs 未收录，故自维护。上游是 Rust + Slint 程序，两处依赖需要显式接线：
#
# 1. 运行时子进程：截图走 `grim`、复制走 `wl-copy`、通知走 `notify-send`、
#    查显示器走 `niri msg`、兜底选字体走 `fc-match`（上游用裸命令名 spawn）。
#    这些不在 Rust 的依赖图里，PATH 缺了就静默降级（通知/字体）或直接报错
#    （截图/复制/多显示器），故 wrapProgram 把它们钉进 PATH —— 消费方只装
#    babry，不必再逐个装运行依赖。
#
#    0.1.4 起才有 `~/.config/babry/config.toml`（`save_dir`）与多显示器支持；
#    0.1.1 的存盘路径写死 `XDG_PICTURES_DIR` / `$HOME/Pictures`，配置文件写了
#    也不读 —— 升级前不要指望 HM 声明的 save_dir 生效。
#
# 2. dlopen 的图形库：Slint 的 winit 后端用 dlopen 取 libwayland-client /
#    libEGL / libGL（二进制里能 grep 到 "libwayland-client.so could not be
#    loaded."），这些不会进 DT_NEEDED，光靠 buildInputs 不够。照 nixpkgs 自家
#    Slint 包 slint-viewer 的做法：autoPatchelfHook + runtimeDependencies 把
#    它们写进 RPATH。libxkbcommon/fontconfig 则是直接链接的（DT_NEEDED 可见）。
#
# `--window` / `-w` 不再调用 `niri msg`：上游已换成自己的 CV 选区，niri 侧
# 只剩「让编辑器全屏」的窗口规则（见 gui/desktop/linux/niri/config/windowrules.kdl）。
#
# 升级改 version + hash + cargoHash（都先填 lib.fakeHash，取报错里的 got:）。
{
  lib,
  stdenv,
  rustPlatform,
  fetchFromGitHub,
  pkg-config,
  makeWrapper,
  autoPatchelfHook,
  fontconfig,
  libxkbcommon,
  libGL,
  libgcc,
  wayland,
  grim,
  wl-clipboard,
  libnotify,
  niri,
}:

rustPlatform.buildRustPackage rec {
  pname = "babry";
  version = "0.1.4";

  src = fetchFromGitHub {
    owner = "kregonia";
    repo = "babry";
    rev = "v${version}";
    # 注意用**去根后**的哈希（fetchFromGitHub 走 stripRoot = true）：
    # 直接拿 `nix store prefetch-file` 的 tar 哈希或裸 fetchzip 默认值会失配
    # （后者与 stripRoot=false 等价，会把 archive 里的顶层目录多留一层，
    # 导致 buildRustPackage 在 vendor 阶段找不到 Cargo.lock）。
    hash = "sha256-C+Aq0QSGM5OC3kxc/AlsDYmeKEaxfY71fqAJ9u/xVb4=";
  };

  # 上游把 Cargo.lock 一并提交（CI 也用 --locked 构建），buildRustPackage 默认
  # 就从 src 里读它。cargoHash 只钉住 vendored 依赖的哈希，与 magpie 的
  # vendorHash 同理：只在 Cargo.toml / Cargo.lock 变动时才需要重算。
  cargoHash = "sha256-T+FZxU6RbduhfvfreNVcctpc/8Su/MLaPPsn+yb9hDc=";

  # 上游 CI 的 Linux 构建依赖（.github/workflows/cargo-linux-multiarch.yml）：
  # build-essential pkg-config libfontconfig-dev libxkbcommon-dev libwayland-dev。
  nativeBuildInputs = [
    pkg-config
    makeWrapper
  ]
  ++ lib.optionals stdenv.hostPlatform.isLinux [ autoPatchelfHook ];

  buildInputs = [
    fontconfig
    libxkbcommon
    libGL
    wayland
    # libgcc：autoPatchelfHook 会整体重写 RPATH，把 rustPlatform 默认带上的
    # cc 运行时路径（gcc-*-lib）一并抹掉，于是 DT_NEEDED 里的 libgcc_s.so.1
    # 找不到（"auto-patchelf could not satisfy dependency libgcc_s.so.1"）。
    # 显式给 libgcc 让 autoPatchelf 能把它写回 RPATH。
    libgcc
  ];

  # autoPatchelfHook 读它来补 RPATH，覆盖 dlopen 的库（libGL 是 libglvnd，
  # 提供 libEGL.so.1 / libGL.so.1）。照 nixpkgs slint-viewer 的清单，
  # 去掉用不到的 X11 侧（babry 是 Wayland 原生，winit 探不到 X11 会自己回落）。
  runtimeDependencies = [
    libGL
    libxkbcommon
    wayland
  ];

  # 上游 0.1.4 的测试套件在构建沙箱里过不了，故关闭 check（上游 CI 也只
  # `cargo build`、从不跑 cargo test）：
  #  - ui_tests 要导出带文字的截图，字体候选只有 /usr/share/fonts/... 和
  #    `fc-match`，沙箱里两者皆无 → 「无法加载文字标注字体」；
  #  - document_tests 的「增量预览 == 全量重放」像素断言对 tool 10 差 1~5
  #    个色阶（多线程重放顺序相关），daemon 的 socket 测试也会偶发抢锁失败。
  # 移除条件：上游修好这三处（或在 CI 里跑 test）后改回默认 checkPhase。
  doCheck = false;

  postInstall = ''
    wrapProgram $out/bin/babry \
      --prefix PATH : ${
        lib.makeBinPath [
          grim
          wl-clipboard
          libnotify
          # 0.1.4 起用 `niri msg -j outputs/focused-output` 选显示器与坐标。
          niri
          # 兜底字体走 `fc-match`（编辑器从 fontconfig 取字体文件）。
          (lib.getBin fontconfig)
        ]
      }
  '';

  meta = {
    description = "Edge-aware screenshot tool for Linux Wayland (niri / Hyprland)";
    longDescription = ''
      Babry captures the screen with grim, then uses local CV (edge, color
      boundary, connected-component and long-line analysis) to propose the
      region under the cursor. Hover to snap, scroll to change hierarchy,
      click to confirm, or drag to fall back to manual selection. Annotation,
      inline text, mosaic/blur, clipboard copy, PNG save and layer-shell
      pinning happen in the same window.
    '';
    homepage = "https://github.com/kregonia/babry";
    changelog = "https://github.com/kregonia/babry/releases/tag/v${version}";
    license = lib.licenses.asl20;
    mainProgram = "babry";
    platforms = lib.platforms.linux;
  };
}
