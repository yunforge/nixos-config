# Fcitx5 中文输入法

配置只有系统层（`modules/nixos/desktop/default.nix`）：负责安装与环境变量。
home-manager 侧不托管输入法的任何文件（原先的 Rime 用户配置已随 Rime 一并删除）。

## system 配置

- 输入法框架：fcitx5（`waylandFrontend = true`）
- 插件：
  - `kdePackages.fcitx5-configtool`：图形化配置工具
  - `kdePackages.fcitx5-qt`：Qt5/6 应用输入法模块
  - `fcitx5-gtk`：GTK3/4 应用输入法模块
  - `msime-fcitx5`：水杉输入法（MSIME）的 Fcitx5 插件

水杉插件由 flake 输入 `msime` 提供，**必须经 overlay 接入**（`modules/nixos/core/default.nix`）：
插件被加载进 fcitx5 进程，只有按本系统的 nixpkgs 构建才能与系统上的 Fcitx5 出自同一份。
`msime-fcitx5` 同时提供 `msime-linux-setup`，故也进了 `environment.systemPackages`。

## 水杉输入法首次配置

安装包不带词库。每个要使用输入法的用户运行一次：

```bash
msime-linux-setup --download
```

或打开「水杉输入法」设置完成首次配置——它下载并校验词库，再把输入法加入当前的输入法列表。
没有自动加入时，用 `fcitx5-configtool` 添加「水杉输入法」。

升级后重启 fcitx5 用户服务（`systemctl --user restart app-org.fcitx.Fcitx5@autostart.service`）
或重新登录即可用上新版本——别用 `fcitx5 -r`，那样拉起的进程会脱离 systemd 单元。

> [!NOTE]
> 上游提供 `programs.msime` NixOS 模块（会一并注册 online / voice / clipboard
> 的 systemd 用户单元）。本仓库目前按上面的方式手工接线，**未接入该模块**，
> 因此联网候选、语音输入与剪贴板历史这些 provider 服务不可用。

## 环境变量

原生 Wayland 应用（GTK3/4、Qt6）**不设** `GTK_IM_MODULE` / `QT_IM_MODULE`：
候选窗走 text-input-v3 → niri（input-method-v2 中转）→ fcitx5 classicui——上游在
[fcitx5-gtk PR #44](https://github.com/fcitx/fcitx5-gtk/pull/44) 的回复中指明的路线
（fcitx5-gtk 的 client-side popover 及其复刻的主题渲染上游已不再维护）。
全局仅保留（`modules/nixos/desktop/default.nix`）：

```nix
XMODIFIERS = "@im=fcitx"; # XIM 兜底：XWayland 下未按应用 wrap 的 X11 应用
SDL_IM_MODULE = "fcitx";
GLFW_IM_MODULE = "fcitx";
NIXOS_OZONE_WL = "1";
```

XWayland 应用不靠全局变量：微信、欧陆词典、WPS 等 Qt 应用由 `lib/default.nix` 的
`wrapQtXWayland` 按应用注入 `GTK_IM_MODULE` / `QT_IM_MODULE` / `XMODIFIERS`
（**Qt5 应用没有 XIM 支持**，`XMODIFIERS` 兜不住它们，必须 wrap，WPS 即此例）。
某个 X11 GTK 应用若 XIM 体验不可接受，照同一模式按应用 wrap `GTK_IM_MODULE=fcitx`。

## 候选词窗外观

主题**不由仓库托管**：本机用 `~/.local/share/fcitx5/themes/msime-fix/`——水杉 `msime` 主题的
本地副本，背景换成自绘的九宫格 `background.png` / `background@2x.png`（R 角 + 柔和投影，**无描边**），
`~/.config/fcitx5/conf/classicui.conf` 的 `Theme` / `DarkTheme` 指向它。

需要副本的原因：水杉插件**每次 fcitx5 启动都重新生成** `themes/msime/theme.conf`（切线位置与
`shape-*.png` 由 `libmsime-fcitx5.so` 在运行时算出，store 里没有可 patch 的源文件），直接改那份会在
下次重启被覆盖。

**路线变更（2026-10-24，10-25 真机验证通过）**：全局 `GTK_IM_MODULE` 已移除（见上文「环境变量」），
Wayland GTK 应用改走 text-input-v3 → classicui，不再经过下述 client-side popover。ghostty、WPS、
XIM 兜底三项手测全部通过后，`nine-slice-overlap.patch` 与 `overlays/default.nix` 的 fcitx5-gtk
override 已于 2026-10-25 退役（X11 下 fcitx5-gtk 的候选窗由 classicui-XCBUI 绘制，不经此代码；
若未来重新启用 popover 路径需恢复补丁）。以下为当时的根因记录：

关键几何约束（2026-10-22 已定位并修复）：候选窗右侧竖切线上的那根 1px 线**不在 classicui 的
瓦片绘制里**——GTK4 应用（ghostty 等）在 `GTK_IM_MODULE=fcitx` 下由**应用进程自己**用 GTK im module
（`fcitx5-gtk` 的 `gtk3/fcitxtheme.cpp::Theme::paint`）拼九宫格画候选窗，classicui 只提供候选数据。
**根因**：GTK 先把整块 paint 录制进 cairo recording surface（`gtk_snapshot_append_cairo`），1.5 倍缩放
发生在回放阶段，录制上下文里 CTM 是单位阵、`device_scale=1.0` ⇒ 在 `paint` 里读缩放再按设备像素量化
切线是**拿不到真值**的（该方案已实现并真机实测无效）。**修复**：`pkgs/fcitx5-gtk/nine-slice-overlap.patch`
（经 `overlays/default.nix` 的 `fcitx5-gtk` override 生效）让相邻瓦片沿共享切线重叠 1 逻辑像素 +
`CAIRO_EXTEND_PAD`，不依赖读取缩放；九片改在 `cairo_push_group` 内用 `CAIRO_OPERATOR_SOURCE` 绘制、
`alpha` 最后整体应用一次（否则半透明的高亮美术在重叠处叠两次 alpha，切口会出现 3 列亮带）。
真机 A/B（同一批 10 组输入、仓库自建产物）未打补丁 7/7 出缝、打补丁 0/8，且高亮行切口列回到与邻列同值。
`[InputPanel/Background/Margin]` 仍取 **4 的倍数**（与切线位置无关，纯审美）。
另有 `pkgs/fcitx5/nine-slice-align.patch`（classicui `sizeHint()` 向上对齐 4 逻辑像素）：它**不是 GTK im
module 那根线的修复**，但让 classicui 路径（原生 Wayland IM，非 GTK 应用）的面板逻辑宽恒为 4 的倍数 ⇒
设备宽恒为 3 的倍数，恰好避开同一显隐律（实测 7/7 组无缝），因此保留；两处细节见 `docs/quirks.md`。
`[InputPanel/ShadowMargin]` 只有 `xcbinputwindow.cpp` 读，Wayland 下**完全不生效**，写不写都行。

高亮条同理但更容易踩坑：`FullWidthHighlight=True` 时它画在
`[ContentMargin] + [TextMargin] − [Highlight/Margin]` 的位置、宽
`窗口宽 − ContentMargin − TextMargin + Highlight/Margin 左右之和`。水杉原主题的
`Highlight/Margin = 10/12` 配的是**无投影带**的平背景，换成带投影的自绘背景后高亮条会盖住投影带、
探出卡片边缘（视觉越界）。本机改为自绘 `highlight.png` / `highlight@2x.png`（半径 4 = margin，
半透明 `#b7d1eb`）并把 margin 取 4/4/4/4，让高亮条落在卡片白区内缩 3 逻辑像素处。

要改候选窗的字体 / DPI / 方向，直接用 fcitx5 的 GUI 配置（`kdePackages.fcitx5-configtool`）
—— 没有 HM 覆盖这些文件，改动会保留。改完主题后重载：

```bash
systemctl --user restart app-org.fcitx.Fcitx5@autostart.service
```

## XWayland 候选窗缩放

fcitx5 的候选窗按“输入上下文所属显示”选后端渲染：原生 Wayland 客户端走 WaylandUI
（跟随合成器分数缩放），XWayland 客户端走 XCBUI，而 XCBUI 的缩放 = `DPI / 96`，
DPI 只取自 X11 的 `Xft.dpi` 资源（RESOURCE_MANAGER）。

xwayland-satellite **≥ 0.8.3** 会在启动及缩放变化时把 `Xft.dpi = 96 × scale`
同步进 RESOURCE_MANAGER（上游 PR #477，2026-09-08 合并，v0.8.3 发布），fcitx5
监听该资源后立即重读，无需重启输入法。

验证：

```bash
xrdb -query                     # desktop 应显示 Xft.dpi:<TAB>144
displays=$(fcitx5-diagnose | grep -c 'Group \[x11::0\]')   # 微信等 X11 客户端所在分组
```

## 输入法切换键

`~/.config/fcitx5/config` 不由 home-manager 托管，键位回到 fcitx5 内置默认。原先那份
「只留 `Ctrl+Space` 切输入法」的托管配置已删除，其中有两点后果值得知道：

- `AltTriggerKeys` 回到默认的 `Shift_L` —— 会在 fcitx5 这层就把 Shift 截走。
- enumerate（轮换）系列回到默认：按住修饰键或 `Super+Space` 会再切一次输入法。

要改键位就用 fcitx5 的 GUI 配置（`kdePackages.fcitx5-configtool`），改动会保留。

## 管理

```bash
# 查看 fcitx5 诊断信息
fcitx5-diagnose
```

- fcitx5 配置目录：`~/.config/fcitx5`
- 水杉的用户数据与词库：`~/.local/share/msime`
- Niri 下已在 `startup.kdl` 中自启 fcitx5；XWayland 应用输入法由 `wrapQtXWayland` 按应用注入的变量接管（Qt5 应用无 XIM 支持，必须 wrap，如 WPS），其余 X11 应用走 XIM

排查时优先看日志（fcitx5 自动启动，stderr 会进 journal）：

```bash
journalctl --user | grep org.fcitx
```

> [!NOTE]
> `fcitx5-diagnose` 的插件列表不可靠——它可能不列出实际加载的插件。

## 迁移记录

原 Rime + 万象拼音（`fcitx5-rime` / `rime-wanxiang`）已移除，包括：

- 系统层 addons 里的 `kdePackages.fcitx5-chinese-addons` 与 `fcitx5-rime`；
- HM 托管的 `~/.local/share/fcitx5/rime/default.custom.yaml`（页大小补丁）；
- Rime 构建缓存失效的手动清理步骤（`rm -rf ~/.local/share/fcitx5/rime/build`）。

旧的 Rime 数据目录不会自动删除；确认不再需要后可手动清理
`~/.local/share/fcitx5/rime`。
