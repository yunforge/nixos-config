# Ghostty 终端

配置位置：`modules/home-manager/gui/apps/shared/ghostty.nix`（HM 的 `programs.ghostty`）；
着色器在 `modules/home-manager/gui/apps/shared/ghostty-shader/`，由 `xdg.configFile` 部署到
`~/.config/ghostty/shader/`。

## 亮/暗跟随

一个选项写两态：

    theme = light:Catppuccin Latte,dark:Catppuccin Frappe

ghostty 按「当前桌面主题」选，读的正是 `theme-apply` 在写的 dconf
`org.gnome.desktop.interface color-scheme`（见 `docs/themes.md` 的真源一段），
所以**新窗口天然跟随**，不需要登记软链、也不需要信号。两个主题 ghostty 自带。

⚠️ 已在运行的窗口不重选主题（亮暗在启动时确定）：按 `ctrl+shift+,`（reload config）
或新开/新分屏即可。实测记录见本次改动的提交信息。

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
