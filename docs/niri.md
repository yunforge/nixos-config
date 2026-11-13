# Niri 快捷键

Niri 配置分两半，`Mod` = `Super`（Windows 键）：

- `modules/home-manager/gui/desktop/linux/niri/config/`（symlink 到 `~/.config/niri`）：多数快捷键、窗口规则、输入与视觉参数
- `modules/home-manager/gui/desktop/linux/niri/default.nix` 中以 KDL 字符串生成、部署到 `~/.config/niri-colors/{layout,overview}.kdl` 与 `~/.config/niri-outputs/outputs.kdl`：壳层配色、概览背景、显示器配置，以及 **`Mod` + `Tab` 系列窗口切换绑定**（在 `overview.kdl` 的 `recent-windows.binds` 里，**不在 `config/binds/`**）

按 `Mod` + `/` 可随时呼出快捷键查看器（Noctalia 的 keymap 面板）。

## 应用启动

| 快捷键 | 功能 |
|--------|------|
| `Mod` + `Space` | Noctalia 应用启动器 |
| `Mod` + `Return` | 终端（Konsole） |
| `Mod` + `Shift` + `Return` | 浏览器（Microsoft Edge） |
| `Mod` + `E` | 文件管理器（Nautilus） |
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

截图走 **Noctalia 自带截图**（不再安装第三方截图工具）。截图先进入内置标注器，
Done 后同时存盘到 `~/Pictures/screenshots` 并复制到剪贴板；标注器内 `Ctrl+C`
只复制、`Ctrl+S` 只存盘、`Esc` 取消。设置声明在 `niri/noctalia.nix` 的
`settings.shell.screenshot`。

| 快捷键 | 功能 |
|--------|------|
| `Mod` + `P` | 区域截图（拖拽选区，然后进入标注器） |
| `Mod` + `Ctrl` + `P` | 整屏截图（当前显示器，然后进入标注器） |
| `Mod` + `Shift` + `P` | 当前窗口截图（然后进入标注器） |

`Mod+Shift+P` 走 `niri-screenshot-window` 而不是 `noctalia msg screenshot-window`：
Noctalia 的窗口截图要求合成器支持 `ext-image-copy-capture-v1`，niri 26.04 未实现
（实测报 "window capture is not available on this compositor"）。该脚本先用 niri
自带的 `screenshot-window` 截到临时文件，再交给 Noctalia 标注器，因此三条截图键的
后续流程（标注、存盘、复制）完全一致。见 `niri/default.nix`。

标注器内无修饰键工具：`m` 移动、`b` 画笔、`h` 高亮、`l` 直线、`a` 箭头、`s` 矩形、
`o` 圆、`t` 文字、`n` 编号、`u` 模糊；`P` 切换是否包含鼠标指针。

> 运行时 `~/.local/state/noctalia/settings.toml` 里的 `[shell.screenshot]` 会覆盖
> Nix 默认值；首次生效需删掉那段再 `noctalia msg config-reload`。

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
- **浮动打开（居中，统一 900×623，比例 13:9）**：Fcitx5 配置、PicGo、qView、LocalSend、微信、QQ、Telegram、Discord、欧陆词典、gnome-text-editor、Pot（含其偏好面板）、magpie、Anki、gapless、FlClash、disktree、bilibili。尺寸取自 Omarchy `Super + O`（float & pin）的 1300×900 比例 —— 取舍见 `windowrules.kdl` 注释。客户端可自选尺寸（微信实测 900×720），规则保证的是初始尺寸
- **微信额外禁止全屏**（`open-fullscreen false`）：XWayland 的 satellite 会把「尺寸等于某块输出」的窗口判成全屏，从而盖掉浮动预设 —— 根因与移除条件见 `docs/quirks.md`
- 全局默认平铺，圆角 8px（`geometry-corner-radius`，原为 24，理由见 `docs/themes.md`）
