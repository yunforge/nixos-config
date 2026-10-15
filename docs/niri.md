# Niri 快捷键

Niri 配置分两半，`Mod` = `Super`（Windows 键）：

- `modules/home-manager/gui/wm/config/`（symlink 到 `~/.config/niri`）：多数快捷键、窗口规则、输入与视觉参数
- `modules/home-manager/gui/wm/default.nix` 中以 KDL 字符串生成、部署到 `~/.config/niri-colors/{layout,overview}.kdl` 与 `~/.config/niri-outputs/outputs.kdl`：壳层配色、概览背景、显示器配置，以及 **`Mod` + `Tab` 系列窗口切换绑定**（在 `overview.kdl` 的 `recent-windows.binds` 里，**不在 `config/binds/`**）

按 `Mod` + `/` 可随时呼出快捷键查看器（Noctalia 的 keymap 面板）。

## 应用启动

| 快捷键 | 功能 |
|--------|------|
| `Mod` + `Space` | Noctalia 应用启动器 |
| `Mod` + `Return` | 终端（Ghostty） |
| `Mod` + `Shift` + `Return` | 浏览器（Brave） |
| `Mod` + `E` | 文件管理器（Nautilus） |
| `Mod` + `Shift` + `M` | 系统监控（btop，浮动窗口） |
| `Alt` + `T` | Pot 划词翻译 |
| `Alt` + `I` | Pot 输入翻译 |
| `Alt` + `X` | Pot 截屏翻译（OCR） |
| `Mod` + `Alt` + `P` | PicGo 上传剪贴板图片 |

## 工作区

| 快捷键 | 功能 |
|--------|------|
| `Mod` + `U` / `I` | 下一个 / 上一个工作区 |
| `Mod` + `Ctrl` + `U` / `I` | 当前窗口移至下 / 上一个工作区 |
| `Mod` + `1`~`9` | 切换到工作区 1-9 |
| `Mod` + `Ctrl` + `1`~`9` | 当前窗口移至工作区 1-9 |
| `Mod` + `Shift` + `U` / `I`（或 `Page_Up/Down`） | 工作区整体上 / 下移 |

## 窗口管理

| 快捷键 | 功能 |
|--------|------|
| `Mod` + `Q` | 关闭当前窗口 |
| `Mod` + `F` | 最大化列 |
| `Mod` + `M` | 窗口最大化 |
| `Mod` + `Ctrl` + `F` | 全屏 |
| `Mod` + `T` | 浮动 / 平铺切换 |
| `Mod` + `Ctrl` + `T` | 切换浮动 / 平铺焦点 |
| `Mod` + `W` | 标签页显示切换 |
| `Mod` + `O` | 窗口总览 |
| `Mod` + `Ctrl` + `O` | 恢复窗口不透明度 |
| `Mod` + `-` / `=` | 列宽 -5% / +5% |
| `Mod` + `Shift` + `-` / `=` | 窗口高度 -5% / +5% |
| `Mod` + `[` / `]` | 窗口靠左 / 靠右（并入列） |
| `Mod` + `Shift` + `A` | 添加窗口到列 |
| `Mod` + `.` / `Shift` + `D` | 从列中移除窗口 |

## 焦点切换

| 快捷键 | 功能 |
|--------|------|
| `Mod` + `←` / `→` | 左 / 右列焦点 |
| `Mod` + `↑` / `↓` | 上 / 下窗口焦点 |
| `Mod` + `Tab` | 下一个窗口（工作区内） |
| `Mod` + `Shift` + `Tab` | 上一个窗口 |
| `Mod` + `` ` `` | 下一个窗口（按应用过滤） |
| `Mod` + `Shift` + `` ` `` | 上一个窗口（按应用过滤） |

> 这四条属于 niri 的 `recent-windows` 切换器，定义在 `~/.config/niri-colors/overview.kdl`（由 `wm/default.nix` 生成），所以在 `config/binds/` 下 grep 是找不到的。

## 截图

2026-10-15 起截图统一走 **babry**（Wayland 原生、CV 智能选区；nixpkgs 未收录，自维护见 `pkgs/babry`）。
niri 自带的 `screenshot` / `screenshot-screen` / `screenshot-window` 三个动作不再绑定，
也没有第二个截图软件 —— 编辑器要求全屏打开的窗口规则见 `config/windowrules.kdl`。

| 快捷键 | 功能 |
|--------|------|
| `Mod` + `P` | 区域截图（悬停吸附到窗口/面板/控件，滚轮换层级，单击确认，拖动精修） |
| `Mod` + `Ctrl` + `P` | 全屏截图（`babry --screen`，截完直接进编辑器） |

编辑器内按键：`Ctrl+S` 存盘、`Ctrl+C` 复制到剪贴板、`Ctrl+Z` / `Ctrl+Shift+Z` 撤销重做、`Esc` 取消；
工具栏图钉把选区钉成屏幕贴图。存盘位置由 babry 自己的对话框决定 —— niri 的 `screenshot-path`
（`config.kdl`）已随 niri 自带截图动作一并删除。

> 原来 `Mod` + `Shift` + `P` 的「窗口截图」不再单独占键：babry 的智能选区本就把窗口当成
> 一个层级，滚轮即可切到窗口/全屏。

## 系统与会话

| 快捷键 | 功能 |
|--------|------|
| `Mod` + `Alt` + `L` | 锁屏 |
| `Mod` + `Alt` + `X` | 会话菜单（关机 / 重启 / 注销） |
| `Mod` + `S` | 控制中心 |
| `Mod` + `,` | Noctalia 设置 |
| `Mod` + `Alt` + `W` | 壁纸切换 |
| `Mod` + `Shift` + `E` | 退出 Niri |
| `Mod` + `Esc` | 强制恢复 / 禁用 Niri 快捷键 |
| `XF86` 音量 / 亮度键 | 音量与亮度控制（Noctalia） |

## 窗口规则（自动行为）

- **最大化打开**：VSCode、Logisim、Brave、Zotero
- **浮动打开（居中，统一 0.50×0.60）**：Fcitx5 配置、PicGo、btop、qView、LocalSend、微信、QQ、Telegram、Discord、欧陆词典、gnome-text-editor、Pot（含其偏好面板）、Thunderbird、magpie、Anki、gapless、Clash Verge、disktree、bilibili
- 全局默认平铺，圆角 8px（`geometry-corner-radius`，原为 24，理由见 `docs/themes.md`）
