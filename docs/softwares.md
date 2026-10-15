# 软件方案

所有应用由 Home Manager 统一管理（`modules/home-manager/gui/apps/`）。

## 桌面环境

| 组件 | 软件 |
|------|------|
| 窗口管理器（desktop） | [Niri](https://github.com/YaLTeR/niri) - Wayland 平铺合成器 |
| 桌面环境（laptop 默认） | GNOME |
| Shell（桌面外壳） | [Noctalia](https://github.com/noctalia-dev/noctalia-shell) - 启动器 / 控制中心 / 壁纸 / 锁屏 |
| 显示管理器 | GDM |
| 输入法 | Fcitx5 + Rime（万象拼音） |

## 终端

| 组件 | 软件 |
|------|------|
| 终端模拟器 | Ghostty（Catppuccin Frappe/Latte，跟随桌面亮暗） |
| Shell | Fish（含大量自定义别名） |
| 终端复用器 | tmux（Omarchy 按键布局，见 `docs/tmux.md`） |
| 终端文件管理器 | Yazi（`y`） |

## 浏览器与通讯

| 类别 | 软件 |
|------|------|
| 浏览器 | Zen Browser（默认）、Brave |
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
| Zotero | 文献管理（⚠️ 暂注释，上游 nixpkgs#568692 修复后恢复，见 `docs/quirks.md`） |
| Anki | 记忆卡片 |
| XMind | 思维导图 |
| Thunderbird | 邮件 |
| Pot | 划词翻译（Alt+T / Alt+I / Alt+X） |

## 媒体与工具

| 软件 | 用途 |
|------|------|
| Freetube / gapless / parabolic | 视频 / 音乐 / 下载（yt-dlp 前端） |
| mpv | 视频播放器，uosc「Cupertino」定制界面（配置整棵 vendored 在 `modules/home-manager/gui/apps/mpv/`，见该目录的 README.md / CUSTOMIZATION.md） |
| OBS Studio | 录屏 / 直播 |
| babry | 全机唯一的截图工具（CV 智能选区 + 标注 + 贴图，Wayland 原生，`Mod+P` / `Mod+Ctrl+P`；nixpkgs 未收录，自维护见 `pkgs/babry`） |
| PicGo | 剪贴板图片上传图床 |
| Mission Center / btop / fastfetch | 系统监控 |
| ddcutil（配合 Noctalia） | 显示器亮度控制 |
| qView / Papers / Foliate / Wike | 看图 / PDF / 电子书 / Wiki |
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
| LXGW WenKai（霞鹜文楷） | 中文衬线阅读 |
| Noto Sans/Serif CJK SC | 中文回退兜底（由 `fonts.enableDefaultPackages` 带入） |
| Source Serif Pro | 英文衬线 |
| Noto Color Emoji | Emoji |
