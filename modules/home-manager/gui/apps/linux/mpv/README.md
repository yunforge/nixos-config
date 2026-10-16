# mpv · Cupertino

面向 Linux 的 mpv 配置，在 uosc 5.13.0 基础上定制轻量 Cupertino 风格界面。

- 透明居中标题栏、红黄绿窗口按钮，随鼠标距离渐显/渐隐。
- 单轨章节分段：常态 3px、悬停 5px，灰白/蓝/红区分普通章节、片头片尾与广告。
- 当前播放位置使用小型矩形图标，支持非线性出入场动画。
- 两侧计时动态留白、thumbfast 悬浮缩略图。
- 快进/后退：点按显示单箭头，连按从内侧生成追赶并合入的箭头，长按连续跳转持续生成箭头，松开后收束；累计秒数随操作更新，并呈现非线性压缩回弹动画。
- 长按右方向键或鼠标右键临时倍速，松开恢复。

## 安装

需要 mpv（建议 0.40+）和 Noto Sans 字体；网络视频另需 yt-dlp。

先备份现有配置，再将仓库内容放入 `~/.config/mpv/`。**不要用上游 uosc 安装器覆盖本仓库的定制 Lua 文件。**

uosc 的平台辅助程序没有纳入仓库。需要在线字幕搜索、下载等辅助功能时，从 [uosc 5.13.0 release](https://github.com/tomasklaen/uosc/releases/tag/5.13.0) 下载发行包，将其中 `scripts/uosc/bin/` 复制到本地同名目录。辅助程序源码位于 [uosc src/ziggy](https://github.com/tomasklaen/uosc/tree/5.13.0/src/ziggy)。

`mpv.conf` 当前为 NVIDIA/Linux 设置了 `vo=gpu-next`、`gpu-api=vulkan` 和 `hwdec=nvdec`。其他显卡可将硬件解码改为 `hwdec=auto-safe`，并按系统调整 GPU 后端。窗口外部圆角由桌面合成器提供。

## 常用操作

| 操作 | 功能 |
| --- | --- |
| 空格 / 单击画面 | 播放、暂停 |
| 左方向键 / 短按右方向键 | 后退 / 快进 5 秒 |
| J / L | 后退 / 快进 10 秒 |
| 长按右方向键或鼠标右键 | 350ms 后临时 2×，松开恢复 |
| 短按鼠标右键 | 菜单（控件上保留原操作） |
| F | 全屏 |
| I | 按需显示 mpv stats |

左方向键和 J/L 支持长按连续跳转；右方向键长按仍为倍速。

原生 mpv OSD 状态文字与进度条已关闭；自定义 uosc 和按需 stats 仍可使用。倍速参数见 `script-opts/hold-speed.conf`，界面参数见 `script-opts/uosc.conf`。键盘相对跳转使用自定义动画；拖动轨道保持直接定位，不累计显示秒数。

本仓库直接修改了 uosc 源码，上游更新会覆盖定制。更多说明见 [CUSTOMIZATION.md](CUSTOMIZATION.md)。

## License & Acknowledgements

原创配置、文档和独立新增代码采用 [MIT](LICENSE)。第三方源码及其衍生修改保留上游许可证，**并非整个目录都被重新许可为 MIT**。

感谢 [uosc](https://github.com/tomasklaen/uosc)、[thumbfast](https://github.com/po5/thumbfast)、[Flutter Cupertino Icons](https://github.com/flutter/packages/tree/main/third_party/packages/cupertino_icons)、[mpv](https://github.com/mpv-player/mpv) 与 MacTahoe/WhiteSur 主题作者。组件清单及许可证见 [THIRD_PARTY.md](THIRD_PARTY.md)。

## 检查

可运行 `lua tests/seek-feedback.lua` 验证快进后退累计、方向切换和计时器清理。`scripts/stats.lua` 是 mpv 原版脚本，应以 mpv 内置 Lua 运行；不适用所有系统 Lua 版本的独立语法检查。
