# Ghostty 终端

配置位置：`modules/home-manager/gui/apps/shared/ghostty.nix`（HM 的 `programs.ghostty`）；
着色器在 `modules/home-manager/gui/apps/shared/ghostty-shader/`，由 `xdg.configFile` 部署到
`~/.config/ghostty/shader/`。

## 光标拖尾

`custom-shader = [ "~/.config/ghostty/shader/cursor_trail.glsl" ]` —— 单个「最简单的
Kitty 样式拖尾」：光标移动时在上一位置与当前位置之间拖出一条四边形残影，颜色取当前光标色
（`iCurrentCursorColor`，同 Kitty `cursor_trail` 默认取光标背景色），越靠后越淡，动画结束消失。
没有彩虹、没有粒子。可调常量在着色器顶部：`DURATION`（时长，默认 0.3s）、
`TRAIL_MAX_OPACITY`（拖尾最大不透明度，默认 0.35）。
改动后 `ctrl+shift+,`（reload config）或新窗口即可看到。

## 主题

固定暗色，用 ghostty 自带的 **Catppuccin Frappe**：

    theme = "Catppuccin Frappe"

它就是仓库工作区一族（Catppuccin Frappe）的那套 16 色，与 Noctalia 调色板
`dark.terminal` 色槽同值，所以终端与 nvim / yazi / btop / eza / fish 仍是同一套配色。

**不再由 Noctalia 渲染**（builtin `ghostty` 模板已从
`modules/home-manager/gui/desktop/linux/niri/noctalia.nix` 的 `builtin_ids` 摘掉）。两个原因：

1. 那个模板的 `apply.sh` 会把 `theme =` 就地改写回 `noctalia`，而配置在本仓库是 HM 的
   只读 store 软链（报「只读文件系统」）；
2. 默认会话已切到 Plasma，Noctalia 不在跑，渲染出的
   `~/.config/ghostty/themes/noctalia` 会停在最后一次的亮/暗状态上（实测停在浅色 Nord）。

⚠️ 已在运行的窗口不重读主题（ghostty 无外部 reload 入口）：按 `ctrl+shift+,`（reload config）
或新开窗口/分屏即可。

## 窗口装饰与磨砂玻璃

- `window-decoration = auto` + `gtk-titlebar = false`：窗口装饰交给 niri
  （本仓库走 `prefer-no-csd` + 自绘圆角/阴影，见 `docs/themes.md`）。
- 终端**自身**保持不透明（`background-opacity = 1.0`）；半透明与模糊由 niri 的
  window-rule 施加，见 `modules/home-manager/gui/desktop/linux/niri/config/visual/frosted-glass.kdl`：
  `opacity 0.85` + `blur`，匹配 `^(ghostty|com\.mitchellh\.ghostty|btop)$`。
  该规则是**唯一**能让终端毛玻璃生效的地方 —— app-id 写错或该文件解析失败，
  现象都是「窗口变回不透明」，且 niri 会因 include 读不到而拒绝**整份**配置。

## 常用命令

```bash
ghostty +list-themes | grep -i catppuccin   # 确认自带主题名
ghostty +validate-config --config-file ~/.config/ghostty/config
ghostty +show-config                        # 看生效后的完整取值
niri msg action load-config-file            # 改完 niri 配置后强制重载
```
