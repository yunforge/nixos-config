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

升级后执行 `fcitx5 -r` 或重新登录即可用上新版本。

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

仓库**不托管** `classicui.conf`：候选窗用 fcitx5 内置的 `default` 主题与内置默认偏好
（字体 / DPI / 候选方向均为 fcitx5 默认值）。

要改候选窗的字体 / DPI / 方向，直接用 fcitx5 的 GUI 配置（`kdePackages.fcitx5-configtool`）
—— 没有 HM 覆盖这些文件，改动会保留。

## XWayland 候选窗缩放（workaround）

fcitx5 的候选窗按“输入上下文所属显示”选后端渲染：原生 Wayland 客户端走 WaylandUI
（跟随合成器分数缩放），XWayland 客户端走 XCBUI，而 XCBUI 的缩放 = `DPI / 96`，
DPI 只取自 X11 的 `Xft.dpi` 资源（RESOURCE_MANAGER）。xwayland-satellite 0.8.2
只把缩放发布在 XSETTINGS 的 `Xft/DPI`（fcitx5 读 XSETTINGS 时只取
`Net/IconThemeName`），且未给 Xwayland 传 `-dpi`，于是微信/QQ 等 XWayland 应用里
候选词停在 1.0x，比 VSCode 等 Wayland 应用小 `scale` 倍。

当前由 `modules/nixos/desktop/niri/default.nix` 的 `xwayland-xft-dpi` wrapper 把
`Xft.dpi = 96 × scale` 写进 X11 资源库，并在 `startup.kdl` 中随 niri 自启；fcitx5
监听 RESOURCE_MANAGER 变化后立即重读，无需重启输入法。各主机的实际值：

| 主机 | `mySystem.desktop.scale` | 写入的 `Xft.dpi` |
| --- | --- | --- |
| desktop | 1.5（monitors 派生） | 144 |
| laptop | 1.25（monitors 派生） | 120 |

> 注：laptop 此前未声明 scale（默认 1），wrapper 在该机为空转，而 niri 实际按
> 1.25 渲染——XWayland 候选词一直偏小。scale 改由 `mySystem.desktop.monitors`
> 派生后两台主机一致，此表随之修正。

验证：

```bash
xrdb -query                     # 应显示 Xft.dpi:<TAB>144
displays=$(fcitx5-diagnose | grep -c 'Group \[x11::0\]')   # 微信等 X11 客户端所在分组
```

> [!TODO] 上游已修复
> xwayland-satellite PR #477（`feat: sync Xft.dpi through RESOURCE_MANAGER`，
> 2026-09-08 合并，关闭 issue #301）在 master 中做了同样的同步。待 nixpkgs 内的
> xwayland-satellite 版本 > 0.8.2 后，删除该 workaround（wrapper + `startup.kdl` 自启项）。

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
