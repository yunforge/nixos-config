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

XWayland 应用仍依赖传统输入法环境变量，已手动补齐：

```nix
XMODIFIERS = "@im=fcitx";
GTK_IM_MODULE = "fcitx";
QT_IM_MODULE = "fcitx";
SDL_IM_MODULE = "fcitx";
GLFW_IM_MODULE = "fcitx";
```

## 候选词窗外观

主题**不由仓库托管**：本机用 `~/.local/share/fcitx5/themes/msime-fix/`——水杉 `msime` 主题的
本地副本，背景换成自绘的九宫格 `background.png` / `background@2x.png`（R 角 + 柔和投影 + 描边），
`~/.config/fcitx5/conf/classicui.conf` 的 `Theme` / `DarkTheme` 指向它。

需要副本的原因：水杉插件**每次 fcitx5 启动都重新生成** `themes/msime/theme.conf`（切线位置与
`shape-*.png` 由 `libmsime-fcitx5.so` 在运行时算出，store 里没有可 patch 的源文件），直接改那份会在
下次重启被覆盖。

关键几何约束：九宫格切线画在 `margin × 缩放` 的设备像素位置，1.5x 下**奇数 margin 必然落在半设备像素上**
（`11 × 1.5 = 16.5`），所以 `[InputPanel/Background/Margin]` 取 **4 的倍数**（1.25x / 1.5x / 2x 都安全）。
`[InputPanel/ShadowMargin]` 只有 `xcbinputwindow.cpp` 读，Wayland 下**完全不生效**，写不写都行。
`pkgs/fcitx5/nine-slice-align.patch`（把候选窗尺寸向上对齐到 4 逻辑像素）目前仍在，但它到底消除了哪条线
还没隔离出来 —— 按上面的算式，光靠偶数 margin 就该让四条外框切线对齐；已连同算式一起报给上游
（[fcitx5#1712](https://github.com/fcitx/fcitx5/issues/1712)），等结论再决定留还是删。

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
- Niri 下已在 `startup.kdl` 中自启 fcitx5；XWayland 应用输入法由 `GTK_IM_MODULE` 等变量接管

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
