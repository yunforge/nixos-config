# babry —— 懂边界的 Wayland 截图工具（上游 kregonia/babry）
#
# nixpkgs 未收录，故自维护。上游是 Rust + Slint 程序，两处依赖需要显式接线：
#
# 1. 运行时子进程：截图走 `grim`、复制走 `wl-copy`、通知走 `notify-send`
#    （上游 src/capture.rs 用裸命令名 spawn）。这些不在 Rust 的依赖图里，
#    PATH 缺了就静默降级（通知）或直接报错（截图/复制），故 wrapProgram
#    把三样钉进 PATH —— 消费方只装 babry，不必再逐个装运行依赖。
#
# 2. dlopen 的图形库：Slint 的 winit 后端用 dlopen 取 libwayland-client /
#    libEGL / libGL（二进制里能 grep 到 "libwayland-client.so could not be
#    loaded."），这些不会进 DT_NEEDED，光靠 buildInputs 不够。照 nixpkgs 自家
#    Slint 包 slint-viewer 的做法：autoPatchelfHook + runtimeDependencies 把
#    它们写进 RPATH。libxkbcommon/fontconfig 则是直接链接的（DT_NEEDED 可见）。
#
# `--window` / `-w` 不再调用 `niri msg`：上游已换成自己的 CV 选区，niri 侧
# 只剩「让编辑器全屏」的窗口规则（见 gui/wm/config/windowrules.kdl）。
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
}:

rustPlatform.buildRustPackage rec {
  pname = "babry";
  version = "0.1.1";

  src = fetchFromGitHub {
    owner = "kregonia";
    repo = "babry";
    rev = "v${version}";
    # 注意用**去根后**的哈希（fetchFromGitHub 走 stripRoot = true）：
    # 直接拿 `nix store prefetch-file` 的 tar 哈希或裸 fetchzip 默认值会失配
    # （后者与 stripRoot=false 等价，会把 archive 里的顶层目录多留一层，
    # 导致 buildRustPackage 在 vendor 阶段找不到 Cargo.lock）。
    hash = "sha256-J/gXsAtMICH/Dikac2ZAwNh2hIdmbDCnDpHZ/rGAokI=";
  };

  # 上游把 Cargo.lock 一并提交（CI 也用 --locked 构建），buildRustPackage 默认
  # 就从 src 里读它。cargoHash 只钉住 vendored 依赖的哈希，与 magpie 的
  # vendorHash 同理：只在 Cargo.toml / Cargo.lock 变动时才需要重算。
  cargoHash = "sha256-wys7Kz/WjboS6n2Z23Y5GOcYO9HDZgrxT8SA9TVUZn8=";

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

  postInstall = ''
    wrapProgram $out/bin/babry \
      --prefix PATH : ${
        lib.makeBinPath [
          grim
          wl-clipboard
          libnotify
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
