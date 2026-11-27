# 自定义包 overlay —— pkgs/ 下自维护包的单一注入点
#
# 消费方：
#   - NixOS 系统级：modules/nixos/core/default.nix 的 nixpkgs.overlays
#   - macOS 系统级：modules/darwin/base.nix 的 nixpkgs.overlays
#   - flake 输出：overlays.default 与 packages.*（见 flake.nix），
#     nix flake check 会评估 packages.*；源码哈希和构建步骤由实际构建验证
#
# 为什么是 { inputs }: final: prev: 而不是裸 final: prev:：
#   windows-vm-media 需要按 flake.lock 的 winapps 输入 rev 固定抓取 oem 脚本，
#   overlay 本身拿不到 flake inputs，只能由调用方注入。
{ inputs }:
final: prev: {
  # Bibata 光标补齐 36px 档位（KDE 1.5× 缩放下 24 逻辑 × 1.5 = 36 物理）
  # ------------------------------------------------------------
  # 上游 x11_sizes 只有 [16 20 22 24 28 32 40 48 56 64 72 80 88 96]，**没有 36**。
  # KDE 光标设为默认 24 逻辑像素、且 Plasma「X11 应用自行缩放」时，X11/Qt5 应用按
  # 设备像素取光标，XCURSOR_SIZE=36 会被 Xcursor 吸附到最近的 32px → 看起来比桌面
  # 小一截。此处把 36 加进 x11_sizes，clickgen 从 256px 母版直接重采样出 36px，
  # 清晰无损。根因与配套（微信单独压 env）见 docs/quirks.md。
  bibata-cursors = prev.bibata-cursors.overrideAttrs (old: {
    postPatch = (old.postPatch or "") + ''
      for f in configs/normal/x.build.toml configs/right/x.build.toml; do
        sed -i 's/x11_sizes = \[16, 20, 22, 24, 28, 32, 40, 48, 56, 64, 72, 80, 88, 96\]/x11_sizes = [16, 20, 22, 24, 28, 32, 36, 40, 48, 56, 64, 72, 80, 88, 96]/' "$f"
      done
    '';
  });

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

  # fcitx5-gtk 的九宫格 1px 缝补丁已于 2026-10-25 退役：全局 IM 变量移除后
  # Wayland 应用走 text-input-v3/classicui，X11 下 fcitx5-gtk 的候选窗由
  # classicui-XCBUI 绘制（不经 gtk3/fcitxtheme.cpp 的 client-side popover），
  # 无消费场景；上游亦拒收此修复（PR #44）。根因记录见 docs/quirks.md。

  # 自打包主题（nixpkgs 未收录）：MacTahoe GTK / 图标主题 / Kvantum(Qt) / SDDM 登录主题
  # 2026-11-22 起无消费方；定义与 overlay 惰性保留，便于回退
  mactahoe-gtk-theme = prev.callPackage ../pkgs/mactahoe-gtk-theme { };
  mactahoe-icon-theme = prev.callPackage ../pkgs/mactahoe-icon-theme { };
  mactahoe-kvantum = prev.callPackage ../pkgs/mactahoe-kvantum { };
  mactahoe-sddm-theme = prev.callPackage ../pkgs/mactahoe-sddm-theme { };

  # WhiteSur-kde：覆盖 nixpkgs 的源码快照，补上 Plasma 6 注销界面
  # （nixpkgs 钉的 2024-11-18 还没有 contents/logout）。
  whitesur-kde = prev.callPackage ../pkgs/whitesur-kde {
    whitesur-kde = prev.whitesur-kde;
  };

  # WhiteSur 的 Plasma 启动画面（注销界面在 HM 里构造完整 shell 包副本）
  # 与 SDDM 登录主题（补 Plasma 6.8 移除的 VirtualKeyboardLoader）。
  whitesur-plasma-splash = prev.callPackage ../pkgs/whitesur-plasma-splash {
    whitesur-kde = final.whitesur-kde;
  };
  whitesur-sddm-theme = prev.callPackage ../pkgs/whitesur-sddm-theme {
    whitesur-kde = final.whitesur-kde;
  };

  # mcpp：C++23 模块优先的构建工具（上游 mcpp-community/mcpp）。
  # 名字不能省成 `mcpp`：nixpkgs 的 mcpp 是 Matsui 的 C 预处理器，同名不同物
  #（打包理由见 pkgs/mcpp-m/default.nix 顶部）。
  mcpp-m = prev.callPackage ../pkgs/mcpp-m { };

  # pingfang-sc：苹果苹方简体（上游 yunforge/Font-PingFang，即 macOS 自带那份 OTF 的
  # 镜像）。nixpkgs 不收录（苹果字体不可再分发），故自维护；unfree，自用。
  # 消费方：modules/nixos/core/locale.nix 的 fonts.packages（所有 Linux 主机的界面主字体）。
  pingfang-sc = prev.callPackage ../pkgs/pingfang-sc { };

  # magpie：多个 AI agent 的统一模型选择器（上游 yetone/magpie，nixpkgs 未收录）。
  # 桌面版经 cgo 链接 GTK3 + WebKitGTK 4.1（闭包约 970 MiB），只给有图形会话的主机；
  # magpie-cli 是同源码的 nogui/CGO_ENABLED=0 终端版，给 WSL 这类主机。
  # 注意：它自带 `magpie update` 自更新，在 store 里必然失败，升级改包的 version。
  magpie = prev.callPackage ../pkgs/magpie { };
  magpie-cli = prev.callPackage ../pkgs/magpie { gui = false; };

  # dalibre：calibre 书库的轻量原生管理器（上游 djyde/dalibre，nixpkgs 未收录）。
  # 预编译 Go 二进制，GTK3 栈全靠 dlopen，故包内用 autoPatchelf 的
  # runtimeDependencies 写 RPATH；Glance（书内网页预览）要 WebKitGTK 4.0，
  # nixpkgs 已移除，该功能不可用（懒加载，不影响其余部分）。
  dalibre = prev.callPackage ../pkgs/dalibre { };

  # misterdownloadmanager：Rust 写的下载管理器（上游 anefzaoui/misterdownloadmanager，
  # nixpkgs 未收录）。取上游预编译 deb，四个可执行文件必须同在 $out/bin：
  # GUI 用 current_exe 的同级路径找浏览器 Native Messaging Host（见包内注释）。
  misterdownloadmanager = prev.callPackage ../pkgs/misterdownloadmanager { };

  # pulse：系统活动监视器（上游 egoist/pulse-feedback，nixpkgs 未收录）。
  # 预编译 Go 二进制，GTK3 栈全靠 dlopen，故包内用 autoPatchelf 的
  # runtimeDependencies 写 RPATH；WebKitGTK 4.1 只给「关于 / 更新说明」内嵌页用
  # （懒加载，缺了不影响主界面）。自更新在 store 里必然失败，升级改包的 version。
  pulse = prev.callPackage ../pkgs/pulse { };

  # flclash：基于 ClashMeta 的代理客户端（上游 chen08209/FlClash）。
  # nixpkgs 2026-08-17 以「用户少 + 无人维护」为由把它从 master 移除
  # （26.05 分支里还留着 0.8.92），本仓库的 nixpkgs 跟 master，故自维护一份。
  # 打包理由与升级步骤见 pkgs/flclash/default.nix 顶部。
  # 属性名与 nixpkgs 那个 throw 墓碑同名，overlay 把它盖掉——本仓库要的是
  # 能用的 flclash，不是 nixpkgs 那句「已移除」的报错。
  flclash = prev.callPackage ../pkgs/flclash { };

  # Windows 客户机装机介质（virtio-win ISO + WinApps oem 脚本）。
  # winappsRev 取自 flake.lock 的 winapps 输入，升级输入后 oem 脚本哈希失配
  # 会显式报错，保证介质与 winapps 版本同步（消费方：modules/nixos/virtualization）。
  windows-vm-media = prev.callPackage ../pkgs/windows-vm-media {
    winappsRev = inputs.winapps.rev;
  };
}
