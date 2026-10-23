# 软件方案

所有应用由 Home Manager 统一管理。本文只列 **Linux 工作站**（desktop / laptop）的 GUI 应用
（`modules/home-manager/gui/apps/linux/` + `gui/apps/shared/`）；各设备的用户环境组合
（工作站 / 服务器 / WSL / MacBook 各装什么）见 `docs/architecture.md` 的「角色组合」，
CLI / TUI / 工具链见 `docs/environment.md`。

## 桌面环境

| 组件 | 软件 |
|------|------|
| 窗口管理器（desktop / laptop） | [Niri](https://github.com/YaLTeR/niri) - Wayland 平铺合成器 |
| Shell（桌面外壳） | [Noctalia](https://github.com/noctalia-dev/noctalia-shell) - 启动器 / 控制中心 / 壁纸 / 锁屏 |
| 显示管理器 | GDM |
| 输入法 | Fcitx5 + Rime（万象拼音） |

## 终端

| 组件 | 软件 |
|------|------|
| 终端模拟器 | Ghostty（Catppuccin Frappe/Latte，跟随桌面亮暗）、Tern（手动装到 `~/Apps/Tern`，见 `docs/quirks.md`） |
| Shell | Fish（含大量自定义别名） |
| 终端复用器 | tmux（Omarchy 按键布局，见 `docs/tmux.md`） |
| 终端文件管理器 | Yazi（`y`） |

## 浏览器与通讯

| 类别 | 软件 |
|------|------|
| 浏览器 | Brave（默认）、Zen Browser |
| 通讯 | Discord、Telegram、微信（XWayland 适配）、QQ |

## 开发工具

| 类别 | 软件 |
|------|------|
| 编辑器 | Neovim、VSCode（**只装本体**，扩展由 VSCode 自带的 Settings Sync 管理，不再由 Nix 声明） |
| IDE | JetBrains CLion（打包时补 skiko 渲染库）、Qt Creator |
| AI 编程 | Claude Code、pi-coding-agent、CodeX |
| Git | git、lazygit、github-desktop |
| 容器 | Distrobox + Podman、Docker 扩展、lazydocker |
| 数据库 / 串口 | HeidiSQL、CuteCom |

## 生产力与笔记

| 软件 | 用途 |
|------|------|
| Obsidian / 思源笔记 | 笔记 |
| Typora | Markdown 写作 |
| Zotero | 文献管理 |
| Anki | 记忆卡片 |
| XMind | 思维导图 |
| Thunderbird | 邮件 |
| Pot | 划词翻译（Alt+T / Alt+I / Alt+X） |

## 媒体与工具

| 软件 | 用途 |
|------|------|
| gapless | 本地音乐播放器 |

| mpv | 视频播放器，uosc「Cupertino」定制界面（配置整棵 vendored 在 `modules/home-manager/gui/apps/linux/mpv/`，见该目录的 README.md / CUSTOMIZATION.md） |
| OBS Studio | 录屏 / 直播 |
| babry | 全机唯一的截图工具（CV 智能选区 + 标注 + 贴图，Wayland 原生，`Mod+P` / `Mod+Ctrl+P`；nixpkgs 未收录，自维护见 `pkgs/babry`） |
| PicGo | 剪贴板图片上传图床 |
| Mission Center / btop / fastfetch | 系统监控 |
| ddcutil（配合 Noctalia） | 显示器亮度控制 |
| qView / Papers / Foliate | 看图 / PDF / 电子书 |
| LocalSend | 局域网文件传输 |
| 欧陆词典 | 查词 |
| 迅雷（xunlei-uos） | 下载 |
| Logisim Evolution | 数字电路模拟 |
| file-roller / Nautilus | 压缩 / 文件管理 |

## 游戏

| 软件 | 用途 |
|------|------|
| Steam | 游戏平台（desktop 主机） |
| MangoHud | 性能监控（游戏启动项：`mangohud %command%`） |
| GameMode | 提频（`gamemoderun %command%`） |
| Gamescope | 独立合成器（`gamescope -- <app>`） |
| steamguard-cli | Steam 2FA 验证码 |

## 系统工具（CLI）

eza、zoxide、bat、fzf、ripgrep、fd、jq、yq、tldr、duf、btop、glow、hugo、ffmpeg、yt-dlp、net-tools、tree、unzip、sysstat

其中 `tldr` 由 `programs.tealdeer` 提供，装的是 Rust 实现的 tealdeer（命令名仍叫 `tldr`）：
页缓存落在 `~/.cache/tealdeer`（不再是 Python 客户端的 `~/.cache/tldr`），配置在
`~/.config/tealdeer/config.toml`，并由 `services.tldr-update`（weekly systemd user timer；
darwin 上是 launchd agent）定期 `tldr --update`。缓存缺失时首次调用会自己拉一份
（`settings.updates.auto_update = true`）。dust / yq / sysstat / git-repo 上游没有
`programs.<name>` 模块，仍在 `home.packages`。

## 字体

| 字体 | 用途 |
|------|------|
| Maple Mono NF（CN） | 等宽 / 代码 |
| HarmonyOS Sans SC | 界面无衬线 |
| CupertinoIcons | mpv 的 uosc 界面图标（随 `gui/apps/mpv` 落到 `~/.local/share/fonts`，名字在 uosc 的 Lua 里写死、字形是 Flutter Cupertino Icons 的私有区码位，故必须自带；同目录还有一支上游的 `uosc_textures.ttf` 在本 fork 里已无调用点，不安装） |
| LXGW WenKai（霞鹜文楷） | 终端/编辑器的 CJK 回退（ghostty 配 Mono 变体）与显式文楷请求 |
| Noto Sans CJK SC | 缺字兜底：谚文、罕用汉字；等宽场景走 Noto Sans Mono CJK SC（`fonts.packages` 显式安装，不依赖默认包集） |
| Noto Serif CJK SC | 衬线链主字体（对位 macOS Songti SC；拉丁字形即 Source Serif 血统，故不单装 Source Serif Pro） |
| Noto Color Emoji | Emoji |
