# 自定义包 overlay —— pkgs/ 下自维护包的单一注入点
#
# 消费方：
#   - NixOS 系统级：modules/nixos/core/default.nix 的 nixpkgs.overlays
#   - macOS 系统级：modules/darwin/base.nix 的 nixpkgs.overlays
#   - flake 输出：overlays.default 与 packages.*（见 flake.nix），
#     nix flake check 会逐一评估 packages.*，nixpkgs 滚动时包级回归
#     （fetch 哈希失配、依赖 API 变更）在 CI 即暴露，不再只靠主机 dry-build 兜底
#
# 为什么是 { inputs }: final: prev: 而不是裸 final: prev:：
#   windows-vm-media 需要按 flake.lock 的 winapps 输入 rev 固定抓取 oem 脚本，
#   overlay 本身拿不到 flake inputs，只能由调用方注入。
{ inputs }:
final: prev: {
  # fcitx5：候选窗面板尺寸对齐补丁（把 sizeHint() 宽高向上对齐到 4 逻辑像素，
  # 让 resize() 逻辑→设备取整与 repaint() 除回来的往返保持精确可逆）。
  # 注意：竖切线上那根 1px 线**不是**尺寸/margin 奇偶造成的（瓦片复刻证明该列被
  # 实心涂白），补丁因此不是已证的修复，只是保留的可疑相关项。不新增符号、
  # ABI 不变，因此 inputs.msime 那份插件 overlay 仍与系统 Fcitx5 同源可用。
  # 根因与移除条件见 docs/quirks.md。
  fcitx5 = prev.fcitx5.overrideAttrs (
    finalAttrs: previousAttrs: {
      patches = (previousAttrs.patches or [ ]) ++ [ ../pkgs/fcitx5/nine-slice-align.patch ];
    }
  );

  # fcitx5-gtk：候选窗竖切线 1px 线的**已证修复**。
  # 真凶是 GTK im module 的 client-side popover（GTK4 应用走 im module 时由应用
  # 进程自己画候选窗），不是 classicui、也不是 msime 插件；九宫格在
  # gtk3/fcitxtheme.cpp 的 Theme::paint 里拼，GTK 先把整块录制进 recording
  # surface、回放时才乘 1.5，所以「按设备像素量化切线」在录制上下文里拿不到
  # 缩放（已真机实测无效）。现补丁改为让相邻瓦片沿共享切线重叠 1 逻辑像素 +
  # CAIRO_EXTEND_PAD，不依赖读取缩放。真机 A/B：未打补丁 4/4 组出缝，打补丁
  # 4/4 组无缝。上游未接受前保留；根因与移除条件见 docs/quirks.md。
  fcitx5-gtk = prev.fcitx5-gtk.overrideAttrs (
    finalAttrs: previousAttrs: {
      patches = (previousAttrs.patches or [ ]) ++ [ ../pkgs/fcitx5-gtk/nine-slice-overlap.patch ];
    }
  );

  # 自打包主题（nixpkgs 未收录）：MacTahoe GTK / 图标主题 / Kvantum(Qt) 主题
  mactahoe-gtk-theme = prev.callPackage ../pkgs/mactahoe-gtk-theme { };
  mactahoe-icon-theme = prev.callPackage ../pkgs/mactahoe-icon-theme { };
  mactahoe-kvantum = prev.callPackage ../pkgs/mactahoe-kvantum { };

  # mcpp：C++23 模块优先的构建工具（上游 mcpp-community/mcpp）。
  # 名字不能省成 `mcpp`：nixpkgs 的 mcpp 是 Matsui 的 C 预处理器，同名不同物
  #（打包理由见 pkgs/mcpp-m/default.nix 顶部）。
  mcpp-m = prev.callPackage ../pkgs/mcpp-m { };

  # magpie：多个 AI agent 的统一模型选择器（上游 yetone/magpie，nixpkgs 未收录）。
  # 桌面版经 cgo 链接 GTK3 + WebKitGTK 4.1（闭包 847 MiB），只给有图形会话的主机；
  # magpie-cli 是同源码的 nogui/CGO_ENABLED=0 终端版，给 WSL 这类主机。
  # 注意：它自带 `magpie update` 自更新，在 store 里必然失败，升级改包的 version。
  magpie = prev.callPackage ../pkgs/magpie { };
  magpie-cli = prev.callPackage ../pkgs/magpie { gui = false; };

  # babry：懂边界的 Wayland 截图工具（上游 kregonia/babry，nixpkgs 未收录）。
  # 全机唯一的截图工具（CV 智能选区 + 标注 + 贴图，键位 Mod+P / Mod+Ctrl+P），
  # 取代此前的 Snipaste 与 niri 自带 screenshot 动作；运行时依赖
  #（grim/wl-copy/notify-send）由包内 wrapProgram 钉进 PATH。
  babry = prev.callPackage ../pkgs/babry { };

  # liquidbird：Thunderbird 的 Liquid Glass 主题（上游 StatIndet/liquidbird，
  # nixpkgs 未收录）。不是 add-on，是 profile 里的 userChrome/userContent 体系：
  # 包只摆好文件，落地见 modules/home-manager/gui/apps/productivity.nix。
  liquidbird = prev.callPackage ../pkgs/liquidbird { };

  # Windows 客户机装机介质（virtio-win ISO + WinApps oem 脚本）。
  # winappsRev 取自 flake.lock 的 winapps 输入，升级输入后 oem 脚本哈希失配
  # 会显式报错，保证介质与 winapps 版本同步（消费方：modules/nixos/virtualization）。
  windows-vm-media = prev.callPackage ../pkgs/windows-vm-media {
    winappsRev = inputs.winapps.rev;
  };
}
