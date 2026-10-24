# 主题与外观

配置位置：`modules/home-manager/gui/desktop/linux/niri/noctalia.nix`（**Noctalia 调色板 + 模板声明，配色的唯一真源**）+ `modules/home-manager/gui/desktop/linux/themes/noctalia-templates/`（eza / fish 模板）+ `modules/home-manager/gui/desktop/linux/themes/variants.nix`（GTK/Qt/图标 的亮暗接线与 `theme-apply`）+ `modules/home-manager/gui/desktop/linux/themes/default.nix`（Qt/GTK）+ `modules/home-manager/gui/desktop/linux/niri/default.nix`（Niri 结构与非配色项）。

整个桌面有**两套外观**，真源是 Noctalia 的 theme mode（状态栏那个主题图标，`noctalia msg theme-mode-toggle`）：
切一下，壳层（macOS 中性灰 + 单一强调色）与工作区（Catppuccin）各自在亮/暗两态之间换，而
「壳层冷中性 / 工作区低饱和」这些约定不变。**所有跟随配色的面都由 Noctalia 按当前调色板渲染**
（终端、状态栏/面板、niri 装饰、yazi、btop、eza、fish，见「Noctalia 统一渲染各应用主题」一节），
只有 GTK/Qt/图标仍走 `theme-apply` 翻软链的老机制（它们保持 MacTahoe）。下面几节里的具体取值
都是**暗色那一套**，亮色的对应值见各文件自己的注释。

## 亮/暗切换

**真源只有一个**：Noctalia 的 theme mode。它带两个执行者：

1. **Noctalia 自己**（`theme.templates`，见下一节）—— 换调色板 / 切亮暗时，它按当前调色板
   重新渲染所有跟随文件（ghostty 主题、btop 主题、niri 装饰、yazi flavor、eza、fish）。
2. **`theme-apply`**（`modules/home-manager/gui/desktop/linux/themes/variants.nix`）—— 只管 Noctalia 不接管的
   那几个面：GTK3/GTK4/图标/Qt/Kvantum（保持 MacTahoe）与 niri 概览底色。做法是把两套变体都
   生成到 `~/.config/theme-variants/`，脚本把活文件软链指到当前模式、写 dconf
   （`color-scheme` / `gtk-theme` / `icon-theme` / 窗口按钮位置）；登录时跑一次，之后由 path 单元
   盯 Noctalia 的 state 目录触发（盯目录是因为它保存走 temp+rename，盯文件会漏事件）。

哪些东西怎么跟：

| 面 | 跟的方式 | 运行中的实例 |
|---|---|---|
| GTK3/GTK4、图标、Qt/Kvantum | `theme-apply` 翻软链 + 写 dconf | GTK 多数要重开（Qt/Kvantum 也要） |
| GTK4 的主题本体 | 一份**模式无关**的 `gtk.css`（浅色整份包在 `@media (prefers-color-scheme: light)` 里） | color-scheme 一变就重算，无需重开 |
| niri 装饰色（焦点环 / 标签指示器 / 插入提示 / 最近窗口高亮） | Noctalia builtin `niri` 模板写 `~/.config/niri/noctalia.kdl` | niri watch 到即重载 |
| niri 概览底色 | `theme-apply` 翻 `niri-colors/overview.kdl` 软链 | niri watch 到即重载 |
| ghostty | Noctalia builtin `ghostty` 模板写 `~/.config/ghostty/themes/noctalia` | **不重选**：新开窗口/分屏，或 `ctrl+shift+,` |
| btop | Noctalia builtin `btop` 模板写 `themes/noctalia.theme` | 下次启动生效 |
| yazi | Noctalia community `yazi` 模板写 `flavors/noctalia.yazi/*` | — |
| eza / fish | 本仓库用户模板（见下节） | fish 新开 shell 生效 |
| fastfetch（config + logo） | 登记进 `myHome.appearance.switchTargets`，翻软链 | 下次启动生效 |
| nvim | 翻一份 `mode.lua`，`theme.lua` 据此设 `vim.o.background`，catppuccin `flavour="auto"` | 要重进（或 `:colorscheme catppuccin`） |
| tmux | 颜色全用 ANSI 名称，配色由终端提供 | 随终端自动跟 |

**降级 / 不跟随的三个面**（有意为之，写在这里免得以后重复怀疑）：

- **fastfetch 不跟随 Noctalia。** 上游有 community 模板，但它的 `apply.sh` 要求 `config.jsonc`
  是**严格 JSON**（带注释直接报错退出），而本仓库那份的注释里写着 10 阶渐变的对比度算据、
  不能丢；且 `apply.sh` 会改写 `config.jsonc`（HM 只读软链）里的 `logo` / `display` 两段。
  继续走 `theme-apply` 翻软链：亮色那份的 10 阶渐变是**重算**的，不是换色值（推导见
  `assets/fastfetch/nixos-01-light.jsonc` 顶部注释）。
- **gtk3/gtk4/qt 三个 builtin 模板不启用** —— GTK/Qt 保持 MacTahoe 自打包完整主题，见「主题栈」。
- **bat 不跟随 Noctalia（社区模板已失效）。** 上游 `bat` 社区模板往 `~/.config/bat/config`
  写 `--theme=noctalia` 并渲染 `themes/noctalia.tmTheme`，但那个文件现由 `programs.bat`
  接管（`modules/home-manager/common/shell/default.nix`），它的 `apply.sh` 开头
  `touch "$config_file"` 打在 HM 只读软链上会以非 0 退出（实测 `Read-only file system`，
  Noctalia 只记日志、不损坏文件）。改为 HM 侧固定 `theme = "auto"` +
  `theme-dark = "Catppuccin Frappe"` / `theme-light = "Catppuccin Latte"`：bat 查终端背景色
  （OSC 10/11）自己选，两态仍是 Catppuccin（与终端 16 色同源），亮/暗照样跟。
  **已知边界**：stdout 不是终端时（管道、fzf 的 Ctrl-T 预览）bat 不做探测，会回落自带默认
  主题（Monokai）—— 与跟随无关，是 bat 自身行为；要固定主题就显式 `--theme=` 或设
  `BAT_THEME`。旧社区模板若还开着，建议在 Noctalia 模板面板里关掉。

## Noctalia 统一渲染各应用主题

Noctalia 是配色的**唯一真源**：`customPalettes.mactahoe` 一份调色板含 `dark` / `light` 两个色块，
切 mode 就是换生效的色块，Noctalia 随即把所有跟随文件重渲一遍。声明在
`modules/home-manager/gui/desktop/linux/niri/noctalia.nix` 的 `settings.theme.templates`：

| 类别 | 启用项 | 产物 |
|---|---|---|
| `builtin_ids` | `ghostty` `btop` `niri` | 各自的 `themes/noctalia` / `noctalia.kdl` |
| `community_ids` | `yazi` | `~/.config/yazi/flavors/noctalia.yazi/` |
| `user` | `eza` `fish` | 本仓库自带模板，见下 |

**用户模板**（上游没有 eza / fish）放在 `modules/home-manager/gui/desktop/linux/themes/noctalia-templates/`，
经 `xdg.configFile` 部署到 `~/.config/noctalia/templates/`，`input_path` 相对 `~/.config/noctalia/`
解析。占位符 `{{ colors.terminal_*.default.* }}` 取自当前调色板的 `terminal` 16 色，与
ghostty / btop / yazi 同源，所以 `ls`（eza）与 shell 语法高亮（fish）跟终端是同一套色。

两个实测踩到的点：

- **eza 的十六进制必须带 `#`。** eza 的 `color_from_str` 只认 `#rrggbb` / `#rgb`，裸十六进制
  静默丢弃（回落成 `None` = 无颜色）。故模板用 `hex` 而不是 `hex_stripped`。
- **fish 恰好相反：不能带 `#`、也不能是 `rgb_csv`。** fish 的 `set_color` 只认裸十六进制
  （`64a02b`）或命名色，给它 `rgb_csv`（`64,160,43`）或 `#` 前缀都会在启动时报
  `set_color: 未知颜色`。故模板用 `hex_stripped`。`fish -n` 只查语法、查不出这个，校验要靠
  `fish_indent --ansi` 真正跑一遍高亮。
- **模板文件里的注释不能出现 `{{ }}`。** 模板引擎把任意 `{{ … }}` 当占位符，注释里写
  `{{ colors.terminal_* }}` 会让整份渲染失败（报 `template error(s); output not written`）。
  注释里只写 `colors.terminal_*`。

**双写者问题与解法**：builtin 模板的 `apply.sh` 会**就地改写应用主配置**（ghostty 的
`theme =`、btop 的 `color_theme =`、yazi 的 `[flavor]`），而这些文件在本仓库是 HM 的只读 store
软链 → 写它会报「只读文件系统」。解法是**让 HM 直接把最终值写进配置**
（`theme = "noctalia"`、`color_theme = "noctalia"`、`[flavor] = noctalia`）：apply.sh 检测到已是
目标值就什么都不做（它的 `cmp` / `grep` 判等成立）。新增跟随面时按同一套路：HM 写最终值，
apply.sh 只负责首渲。

## 主题栈

| 项目 | 主题 | 说明 |
|------|------|------|
| GTK3 | **MacTahoe-Dark** | 自定义打包主题（`pkgs/mactahoe-gtk-theme`） |
| GTK4 / libadwaita | **MacTahoe-Dark** | 须显式设 `gtk.gtk4.theme`：HM 26.05 起其默认值为 `null`，不设就不会生成 `gtk-4.0/gtk.css`，应用会退回原生 Adwaita |
| color-scheme | **dark** | `gtk.colorScheme`；写 dconf `color-scheme=prefer-dark` 与 GTK4 的 `gtk-interface-color-scheme=2`，libadwaita 依此判定深色 |
| 图标 | **MacTahoe-dark** | 自定义打包图标（`pkgs/mactahoe-icon-theme`），为深色背景设计 |
| 光标 | **Bibata-Modern-Classic** | 24px，XWayland 亦生效（软链到 `~/.local/share/icons`）；Bibata 只内嵌 16/20/22/24/28/32/40/… 整数档。**另有一份 `icons/default` 指向同一主题**：XWayland 上的 Qt5（微信）会退到字面量 `default`，缺它即回落 X 核心字体光标，见 `docs/quirks.md` |
| Qt | **Kvantum + MacTahoeDark** | `QT_STYLE_OVERRIDE=kvantum`；主题来自自打包的 `pkgs/mactahoe-kvantum`（与 GTK 侧同一个上游作者），见下文 |
| GDM 登录界面 | MacTahoe | 本仓库不再装 GNOME 会话，只留 GDM 做登录器；其 greeter 用的 gnome-shell 由 GDM 自己的闭包提供，靠 overlay 覆盖 `gnome-shell-theme.gresource` 换肤，**字体 / 图标 / 光标 / 壁纸**也一并声明（不然 greeter 会退回 Adwaita 默认），全部在 `modules/nixos/desktop/gdm.nix` |
| Niri 装饰配色 | **Noctalia 调色板** | 由 builtin `niri` 模板写 `~/.config/niri/noctalia.kdl`（焦点环 / 标签指示器 / 插入提示 / 最近窗口高亮）；HM 只留结构项（宽度、几何、阴影），见下文 |
| Niri 概览底色 | MacTahoe 同源 | `niri-colors/overview.kdl`，暗 `#242424` / 亮 `#FFFFFF`（Noctalia 的 niri 模板不管这一项） |
| Noctalia Shell | **自定义调色板 `mactahoe`** | `customPalettes.mactahoe`，色值与 GTK/Qt/niri 同源；界面字体 HarmonyOS Sans SC。**仅调色板归 Nix，bar 布局归 GUI**，见下文 |
| 壁纸 | **默认集纳管**（`assets/wallpapers/`） | `mySystem.desktop.wallpapers` 首项即默认；桌面会话与 GDM 登录界面共用同一张，可覆盖，见下文 |

## 字体

- 界面字体：HarmonyOS Sans SC（12pt）
- 中文衬线阅读：LXGW WenKai（霞鹜文楷）
- 代码 / 终端：Maple Mono Normal NL NF（CN）—— 特意取 `-unhinted` 构建
- 中文兜底：Noto Sans/Serif CJK SC（fontconfig 别名加固，防止国产 Qt 应用缺字方块）

**字形渲染：灰度 + 不 hinting**（`modules/nixos/core/locale.nix`）。hinting 把笔画对齐到像素网格、次像素渲染借 R/G/B 子像素换横向分辨率；两者都是为小字号抢清晰度，代价是字形失去原本比例、字边出现彩边 —— 这里两个都不要，与 macOS 自 Mojave 起的取向一致。autohint 与字体选型尤其矛盾：等宽字体特意选了 `-unhinted` 构建（同一包有 hinted 变体而没选），而 autohint 正是对**没有自带 hinting** 的字体生效的开关。

## Niri 视觉细节

- 窗口间距 8px（见下），单列工作区自动居中（有意为之的"专注模式"，`Mod+F` 可把单列铺满）
- 焦点环 1px，**中性发丝线**（颜色由 Noctalia 渲染，说明见下）
- 窗口圆角 **8px**（`windowrules.kdl` 的 `geometry-corner-radius`），禁用边框。取值参考 Omarchy 的 8（原为 macOS 阶梯的 24），见下
- 标签指示器在列右侧，圆角 2px（3px 宽的条，半径 ≥ 半宽就是胶囊，不超过窗口圆角）；**仅当列进入 tabbed 显示模式（`Mod+W`）时出现**
- 概览缩放 0.50，背景暗 `#242424` / 亮 `#FFFFFF`
- `recent-windows` 高亮框圆角 8px（与窗口圆角同档；Omarchy 无对应项）
- 模糊 `passes 4 / offset 5.0 / saturation 1.10`；终端（ghostty / btop）`opacity 0.85`，取值按最坏情况（近纯白壁纸）下的文字对比定，前提见下文壁纸一节
- 窗口阴影由合成器提供（`shadow { on }`，参数由 MacTahoe 自己的 CSD 阴影反推，见下）
- 窗口开/关动画 220ms / 180ms（退场比入场快；scale 0.96→1.0 + 淡入，不用自定义波纹 shader）

### 圆角为何是 8px（原为 macOS 的 24）

**当前取 8**，参考 Omarchy（Arch + Hyprland）：它默认是直角（`decoration.rounding = 0`，手册
给出的圆角档是 **8**）；原来的 24 照 macOS 的 concentricity 阶梯取、与 MacTahoe-Dark 主题自己
的窗口档 1:1，看下来太圆，故降档。

**未解**：主题内层仍有 `19 / 18 / 16 / 14 / 12` 的圆角，比窗口的 8 更圆 —— 正是下面
「内层不能比外层更圆」那条的反面。压平内层要用 `gtk.gtk{3,4}.extraCss` 覆盖 5 个以上选择器
（主题更新后会静默失配），还没做；先看视觉能否接受，不行就在「降档 + 压内层」与「回到主题
自己的 24」之间选。

#### 原 24 的推导（判据仍适用，数值已不再沿用）

Apple 在 WWDC 2025 的 *Build an AppKit app with the new design* 里把新设计概括为 **concentricity**：每个内层元素的曲率都落在容器圆角之内（`r_inner = r_outer − inset`），而且**窗口圆角随窗口样式变化**：

> *“Windows with toolbars now use a larger radius … Titlebar-only windows retain a smaller corner radius.”*

对应数值：Tahoe 的标题栏型窗口默认为 **16**，带工具栏的用更大的半径；Sequoia（macOS 15）为 **10**（来源：`m4rkw/macos-corner-fix` 的对照表）。

MacTahoe-Dark 在 `gtk-4.0/gtk.css` 里实现的正是这套阶梯，基准 **24**；逐行对照表在
`modules/home-manager/gui/desktop/linux/niri/config/windowrules.kdl`（表只此一份 —— 那里才是改的时候会打开的文件）。

**为何取主题的 24 而不是字面的 16**：内层元素是 18/19px，把窗口压到 16 会让内层比外层更圆，必须连带重写窗口 + 侧边栏 + notebook + tab 共 5 个选择器（via `gtk.gtk{3,4}.extraCss`），且主题更新后会静默失配。取 24 则**零主题覆盖**，而且 GTK 自绘（24）与不自绘圆角的应用（Electron / Chromium / X11：VSCode、Discord、QQ、Telegram、Zotero、Typora、Anki、Steam）终于一致——这才是这套圆角在修的事。macOS 的 24 属于"带工具栏窗口"那一档，与本机以工具栏密集型应用为主的实际场景相符。

**阴影：由合成器接管（之前的"代价"已消解，而且我之前的判断也算错了）**

我把 `clip-to-geometry` 的影响误判为"只裁掉角上的阴影三角（12px 时 123 px²、24px 时 494 px²）"。实际不是：niri 裁的是 `xdg_surface` 的 window geometry，而 GTK 的 CSD 阴影画在 geometry **之外**的边距里 —— 所以 CSD 自绘阴影是**整层消失**的（上下左右全没），这一点就写在 `clip-to-geometry` 的文档里（*“cut out any client-side window shadows”*）。

也就是说在开启合成器阴影之前，窗口是**完全没有任何阴影**的。现在由 niri 提供：

```kdl
shadow {
    on
    softness 32        // = MacTahoe 三层阴影里最大的 blur（0 12px 32px）
    spread 0           // = 三层模糊层的 spread 都是 0
    offset x=0 y=7     // = 三层偏移 3/7/12 按各自 alpha 加权的中值
    color "#00000059"   // ≈ 35%，三层在窗沿处叠加后的等效不透明度
}
```

推导过程写在 `modules/home-manager/gui/desktop/linux/niri/default.nix` 的注释里。三个要点：

- **不会叠成两层**。niri 文档：设了 `prefer-no-csd` 与/或 `geometry-corner-radius` 之后，*“These will also remove client-side shadows if the window draws any.”* 而且无论 GTK 是否响应 `prefer-no-csd`（保留 CSD / 放弃 CSD），结论都一致：要么自绘阴影被裁、合成器补上，要么本来就没有
- `draw-behind-window` 保持默认 `false`——文档说只有"niri 不知道 CSD 圆角"时才需要 `true`；我们给了 `geometry-corner-radius`，niri 自己知道圆角，也就不会在半透明窗口（ghostty 0.85）里透出一圈暗影
- 阴影跟随 `geometry-corner-radius` 绘制（现为 8px），天然与窗口同心

仍可选的另一条路：改回字面 macOS 值 16，并按 concentricity 把上表里 ≥ 18px 的选择器用 `gtk.gtk{3,4}.extraCss` 一并下移。


### 窗口间距为何是 8px

窗口圆角是 8px（`windowrules.kdl` 的 `geometry-corner-radius`），间距若小于圆角的一半，相邻
两窗的圆角弧比自己半径还靠得近，缝隙看上去是"被掐住"而不是留白 —— 8 就是这条判据在圆角 8 下
的下限（原来 12 配的是 24）。

`gaps` 同时作用于内缝隙与外留白。想分开（如 Omarchy 的 `gaps_in 5` / `gaps_out 10`）用
`struts`（niri wiki: Layout#struts，**正值 = 外间隙**；负值是把窗口推出屏幕外那条路，方向相反），
但左右方向的 struts 会让侧边窗口"探头"（niri 文档明说），故未采用。

### 焦点环为何是中性色，而不是强调色

原来这里是 3px 的 `#0088FF`（饱和强调色），视觉上显得抢眼。

**根本理由：Apple 从不把强调色放在窗口边界上。** macOS 用强调色标**控件**（按钮、输入框焦点、选中的列表行），窗口边界只靠中性发丝线（主题里就是 `rgba(255,255,255,.15)` 那一条，也是 Noctalia 调色板 `mOutline = #454545` 的来源）加阴影区分活动与否。所以那个 3px 饱和蓝边是整套改造里**唯一“不像 macOS”的地方** —— 它比任何别的元素都跳，正是因为它同时具备高饱和度和位置错误两个特点。

> **归属变更**：焦点环等 niri 装饰的颜色现在由 Noctalia 渲染（builtin `niri` 模板 → `noctalia.kdl`），
> 用调色板的语义角色而不是写死的 MacTahoe 取色 —— 焦点环取 `mOutline`（中性发丝线）、
> 非焦点面取 `mSurface`（中性面）、紧急取 `mError`（`#ED5F5D`）。上面那段“用中性色而非强调色”
> 的结论不变，只是取值随之从“手挑 MacTahoe 灰”变成“调色板角色”，换主题时自动跟随。
> Nix 侧（`modules/home-manager/gui/desktop/linux/niri/default.nix`）只留结构项。下表的对比度算据是当初选
> `#999999` 时算的，换成 `mOutline` 后量级相当。

**宽度取 1**：niri 把逻辑像素按缩放取整到物理像素。宽度 1 在 desktop 的 1.5 倍下为 1.5 → 取整 2 物理；laptop 的 1.25 倍下为 1.25 → 取整 1 物理（更细，仍可见）。宽度 2 在 desktop 下是 3 物理像素，已明显粗于发丝线。取整表在 `modules/home-manager/gui/desktop/linux/niri/default.nix` 的 `mkLayout`（表只此一份）。

**为何不靠降不透明度来减重**：焦点环画在 8px 缝隙上，背景就是壁纸，而降不透明度在亮壁纸下会让它消失：

| 不透明度 | 压在暗壁纸 | 压在亮壁纸 |
|---|---|---|
| 100% | `#0088FF` | `#0088FF` |
| 60% | `#0E61AE` | `#66B8FF` |
| 45% | `#13528F` | `#8CC9FF` ← 亮度与壁纸几乎相同，**提示失效** |

所以减重只能靠**宽度和色相**。中性灰在两种壁纸上都立得住（暗壁纸 5.4:1、亮壁纸 2.9:1），而纯白在亮壁纸上会消失。当初选 `#999999` 的两个依据：它在 MacTahoe-Dark 的 `gtk-4.0/gtk.css` 里（出现 3 次），而 niri 自己（`default-config.kdl`）也把它当作 recent-windows 高亮框的默认中性色；调色板里的对应角色是 `mOutline`。

### 两处容易搞错的 niri 语义

改动这套配色时踩到过，记录避免重蹈：

- **`focus-ring.inactive-color` 在单显示器上永不可见**。焦点环只围绕每块显示器上的活动窗口，所以 inactive-color 只会在非焦点显示器上出现（niri wiki, Configuration: Layout）。它不是什么“非焦点窗口的描边”。
- **`overview.backdrop-color` 的 alpha 通道会被忽略**（niri wiki, Configuration: Miscellaneous），写成 `#242424cc` 与 `#242424` 等价。

## Qt：从 Adwaita 换成 Kvantum

**问题**：Qt 侧原先用 `adwaita-dark`（Fedora 的 Adwaita Qt 移植）。Adwaita 是另一套设计语言——控件形状、按钮、输入框都与 MacTahoe 无关，而本机有 VLC（UI 面积最大）、Telegram、qView、fcitx5 配置工具四个 Qt 应用，它们的菜单 / 对话框 / 工具条会明显“不像这个桌面”。

**方案**：Kvantum（SVG 驱动的 Qt 样式引擎）+ `vinceliuice/MacTahoe-kde` 的 Kvantum 组件——**与 GTK 侧的 MacTahoe 是同一个上游作者**，本来就是配套的。

自打包为 `pkgs/mactahoe-kvantum`，只取上游的 Kvantum 部分（plasma / aurorae / look-and-feel 面向 Plasma 桌面，与本机无关，装进来只增大闭包）。三处工程细节：

1. **主题包进 `home.packages`，不用 `qt.kvantum.themes`。** 后者会把 `~/.config/Kvantum` 整个做成指向 store 的软链，而 `kvantum.kvconfig` 又要写在同一目录下，两者会打架。装进 profile 后落在 `XDG_DATA_DIRS`，Kvantum 同样会在那里搜主题（上游自己的 `install.sh` 就是装到 `share/Kvantum`）。

2. **主题名取 `MacTahoeDark` 而不是 `MacTahoe`。** Kvantum 选浅色还是深色取决于应用的 QPalette 明暗，而非 Plasma 会话下这个值来自平台主题，并不可靠。上游目录里浅深两态并存（`MacTahoe.kvconfig` / `MacTahoeDark.kvconfig`），Kvantum 的规则是“主题 T → `T.kvconfig`；若应用偏暗且存在 `TDark.kvconfig` 则改用它”——所以把深色那一对单独命名为主题 `MacTahoeDark` 后，选中它必然命中深色档（它要去找的 `MacTahoeDarkDark.kvconfig` 并不存在）。与本仓库其余部分“只用深色”一致。

3. **强调色对齐壳层。** 上游 kvconfig 用 `#a0b4f8`（浅紫蓝）作 highlight，而同一个作者的 GTK 主题用的是 `#0088FF`——同源却不同色。打包时把 highlight / inactive.highlight / link 统一到 `#0088FF`，与 GTK、Noctalia 的 `mPrimary` 一致（
   焦点环是例外，它故意不用强调色，见上文）。

**`platformTheme` 保持 `adwaita` 不动**：Wayland 下 Qt 的窗口装饰由平台主题提供，与控件样式是两回事；换掉它会让自绘标题栏消失（`env.nix` 里就是为此才恢复 Qt 自绘）。所以现状是“控件 = Kvantum/MacTahoe，标题栏 = QAdwaitaDecorations”。

> 后续实测修正：niri 开了 `prefer-no-csd` 之后 Qt 6 根本不画标题栏（Qt 显式请求 server-side decoration，
> 见下面「窗口按钮布局」一节），所以 QAdwaitaDecorations 在这台机器上其实没有被用到。

**未验证的一点**：MacTahoeDark 的底色 / 文字本来就与 MacTahoe-Dark 的 GTK 值一致（`window.color=#242424`、`text.color=#dedede`、`tooltip.base.color=#333333`，可直接 grep 自打包产物复核），但 Kvantum 的实际渲染要打开 VLC 或 Telegram 看一眼才算数。

## 窗口按钮布局：为什么红绿灯不能全局

按钮布局只有一个真源：`variants.nix` 的 `buttonLayout = ":minimize,maximize,close"`。它被
写成 dconf 的 `org.gnome.desktop.wm.preferences button-layout`（GTK3/GTK4 ini、`theme-apply`
的 `gsettings` 都跟着它走），是左侧留空、三个按钮全在右侧、**关闭在最右**。

**红绿灯（macOS 三色圆钮）无法全局化**——这是实测结论，不是取舍：

| 框架 | 按钮由谁画 | 能否红绿灯 |
|---|---|---|
| GTK3 / GTK4 / libadwaita | GTK 主题的 CSD（`button.titlebutton`） | ✅ MacTahoe 直接给 PNG 三色灯 |
| Thunderbird（LiquidBird） | 主题自带 PNG | ✅ 已按同一顺序重排（见 `productivity.nix`） |
| mpv | uosc 自绘（`TopBar.lua`） | ✅ 按 MacTahoe SVG 的颜色/几何画圆 |
| Chromium / Brave / Electron | 各自的 `views` 绘制 | ❌ 只有单色符号（`– □ ×`），顺序跟随 dlopen 的 GTK 布局 |
| Qt6（Telegram / qView / VLC…） | Qt 自己 | ❌ **在 niri + `prefer-no-csd` 下根本不画标题栏** |

Qt 那条是硬伤：`QWaylandXdgSurface::Toplevel::requestWindowFlags` 会显式调用
`requestMode(mode_server_side)`，而 niri 永远不画 SSD、客户端又据此抑制 CSD，结果就是无边框。
Qt 侧唯一的红绿灯方案是第三方 `whitesur-qt-decoration` 插件（未打包、私有 Qt ABI，Qt 升级即静默失效），
故不采用；Qt 自带装饰插件（`libbradient`、`libqadwaitadecorations`）也只画单色符号。

**因此全局统一的基准取“位置 + 顺序”，而不是“画法”**：右侧、左起 最小化 → 最大化 → 关闭。
GTK 主题因此渲染成 黄-绿-红（红=关闭仍在最右），Chromium/Qt 渲染成 `– □ ×`——位置和顺序一致，
视觉风格随框架。若哪天要“看起来更像 macOS”，唯一的全局办法是把 GTK 那三个 PNG 换成单色符号
（已验证可用 CSS 覆盖成平面 `– □ ×`），代价是失去红绿灯。


## 双层配色模型

壳层与工作区分属两套家族，这是**刻意的**，不是遗漏：

| 层 | 家族 | 元 |
|---|---|---|
| 壳层：niri 装饰 + GTK + Qt + Noctalia bar | macOS 中性灰 + 单一强调色 `#0088FF` | MacTahoe-Dark 的 `gtk-4.0/gtk.css` |
| 工作区：终端 + 编辑器 + shell + 文件管理器 + 系统监控 | 暗 Catppuccin Frappe / 亮 Catppuccin Latte | **Noctalia 调色板的 `terminal` 色槽**；ghostty、Neovim、yazi、btop、fastfetch、eza、fish 多处同源 |

> 工作区一族现在也由 Noctalia 的 `terminal` 色槽统一供色：暗色块填 Frappe、亮色块填 Latte，
> 亮暗切换时整族一起换（ghostty/btop/yazi/eza/fish 由 Noctalia 模板渲染，nvim/tmux/fastfetch 随终端或自行跟随）。
> **亮色块必须显式填 `terminal`**：Noctalia 在色块缺 `terminal` 时自行推导，实测推导把绿色槽给成了蓝色
> （`mactahoe` 只填 `dark.terminal` 时，亮色渲染出 `palette2 = #0076df`）。

**“选中 / 活动”的归属**（这是决定，不是默认）：壳层的蓝只标**壳层控件**（按钮、输入框焦点、niri 标签指示器）；工作区里“选中”一律用 Catppuccin 的强调色 **mauve** —— 终端选区与编辑器同源。终端光标是唯一例外，保持 rosewater（Catppuccin 对终端光标的约定，光标不是“选中”）。理由：终端选区与光标会**同屏出现**，rosewater 与 mauve 一暖粉一冷紫，分属两套会让它们看着来自不同系统。

选这个组合的理由：一是 GTK/GDM/图标/自打包已经全部在 MacTahoe 上，二是“macOS 壳 + 低饱和冷调工作区”比单纯的全局 Catppuccin 更有辨识度。

**定调：以应用层为主体。** bar 应当退到背景里，而不是与窗口争主体。这条决定了下面 Noctalia 一节的取舍。

### fastfetch：logo 与 10 阶渐变

细节全在 `assets/fastfetch/nixos-01.jsonc` 的注释里，两个结论：

- **logo 是 DeepSeek 像素鲸鱼，走文件（文本）而不是内置 logo。** fastfetch 内置 logo
  不可着色 —— 实测 `--logo-color-1..9` 对它完全无效（输出逐字节相同）。而文本文件可以
  逐行内嵌真彩色 ANSI，于是能用**半块字符**（`▀`/`▄`）一个字符塞两个像素：前景 = 上半
  像素、背景 = 下半像素，32×22 的像素图只占 32 列 × 11 行；腹部冰蓝、白色前鳍这些
  亮度差靠背景色画出来，纯前景色的 ASCII 画不出来。
  文件：`assets/fastfetch/logo/deepseek_whale{,-light}.txt`，由 `common/tools/default.nix`
  部署（暗色 / 亮色两套调色板，浅底上原蓝会糊）。图形取自 @lhh010 的手绘像素材
  （`dsh-ui-whale`），经 MIT 许可的 `ccch1mneyyy/dsh-TUI` 转成半块像素图。
  ⚠️ 文件路径写错时 fastfetch **静默回退到内置 logo**（不报错）—— 量宽度时踩过一次，
  以为在量鲸鱼，其实量的是内置 NixOS ASCII。
- **那 10 个常量是冷色明度渐变，不是彩虹。** 它们会被用在约 30 个键名标签上
  （`├ Board` / `├ CPU` …），10 个色相铺满一列文字就是噪声。
  而原设计的端点是 NixOS 品牌蓝 `#5277C3`，压在终端底色 `#303446` 上只有 **2.81:1**
  （低于 AA），最上面几行的键名本身就偏暗 —— 所以这里既修可读性，也修配色家族：
  改为经过 4 个 Frappe 真实色的关键帧插值（`overlay2` → `blue` → `sapphire` → `sky`），
  10 阶全部 ≥ 4.53:1。

- **宽度预算 ≲ 100 列**（半屏终端），实测最长 **90 列**。历史上是 133 列：分组横线原来是
  10 段 × 7 字符（横线自己就有 70 列）+ 43 列的 logo。收的过程：横线改 10 段 × 2 字符；
  logo 换 32 列的鲸鱼；模块格式只留有效字段（`os` 名字+版本、`disk` 不留文件系统类型、
  `localip` 不留 MAC、`display` 分辨率+刷新率、`packages` 改 `nix: A+B`）；模块清单也砍了
  一批（Board / Sound / BIOS / Packages / Processes / Term Font / BT Radio / WiFi / DNS /
  Public IP / 日期时间 / 运行时长）。
  量法：`fastfetch --pipe -c assets/fastfetch/nixos-01.jsonc` 后取最长行（**先把 logo 路径
  换成绝对路径**，否则静默回退到内置 logo，量出来的宽度是假的）。
  信息头（键名）改成中文，按显示宽度手工补空格到 8 列 —— fastfetch 不会自己对齐 CJK。
  分组收敛成三组：**硬件 / 软件 / 网络**（原来的 Time 组只剩「系统年龄」一行，并进软件组）。
  用量相关的三行（memory / swap / 两块 disk）统一成 `已用 / 总量 (百分比)`，**没有进度条**：
  memory / swap 的 `percent` 覆盖块直接删掉（阈值本来就只作用于进度条），disk 用
  `{size-percentage}` 把百分比内联进 `format`。还想更窄只剩两个杠杆：去掉
  `Font` / `Vulkan` / `OpenGL` / `BT Radio` 几行、把 logo 换窄一档。

## Noctalia：调色板归 Nix，其余归 GUI

这是最容易误解的一块，先讲清机制。

```
programs.noctalia.settings  →  ~/.config/noctalia/config.toml      ← Nix 管理
                                        ↓  被运行时覆盖
GUI 里的任何改动            →  ~/.local/state/noctalia/settings.toml ← 真实状态，Nix 管不到
```

模块自己的文档写着（`nix/home-module.nix`）：

> *“Default settings for noctalia … **Note: these settings can still be overwritten at runtime via the settings menu.**”*

所以 Nix 里的 `settings` **只是出厂默认值**。实测对账：

| 键 | 仓库里声明的 | 实际生效的 |
|---|---|---|
| `theme.builtin` | `Catppuccin` | —（已删，见下） |
| `audio.enable_sounds` | `false` | **`true`** —— 出厂默认被 GUI 推翻（见下） |
| `audio.enable_overdrive` | `true` | 在 settings.toml 里 → 以 GUI 为准 |
| `brightness.enable_ddcutil` | laptop 上 `false` | desktop 实测 `true`（laptop 需单独核） |
| `shell.font_family` | `HarmonyOS Sans SC` | 不在 settings.toml → **生效** ✅ |
| `bar.default.background_opacity` / `start` / `center` / `end` | `0.30` / 三处控件清单 | state 里有旧值 → **遮蔽**，要删一次才生效 |

audio 那组里 `sound_volume` / `volume_change_sound` / `notification_sound` 已删：它们服务的功能被
`enable_sounds = false` 关掉，留着就是服务死功能的旋钮（以后开音效时 GUI 会自己写回去）。

**职责划分（这是决定，不是妥协）**：

- **调色板归 Nix**：`programs.noctalia.customPalettes.mactahoe` 写 `~/.config/noctalia/palettes/mactahoe.json`，配合 `theme.source = "custom"`。这是唯一能在版本控制里钉死“MacTahoe 中性灰 + `#0088FF`”的入口
- **模板声明（`theme.templates`）归 Nix**：见「Noctalia 统一渲染各应用主题」。⚠️ 同 `bar.default` 的坑 —— 运行时 `settings.toml` 里若已有 `[theme.templates]` 段会**整体覆盖**这里，首次生效需把那段删一次再 `noctalia msg config-reload`
- **bar 布局的四项归 Nix**：`bar.default` 的 `background_opacity` / `start` / `center` / `end` —— 它们没有密钥，可以声明式
- **bar 其余键与插件配置归 GUI**：前者是 `capsule` / `enabled` / `margin_edge` 这类外观键，后者在 `settings.toml` 里且包含明文 API key（`[plugin_settings."coder/deepseek_usage"]` 的 `api_key`）。托管插件配置等于把密钥写进全局可读的 store，与当初 WinApps RDP 密码做到一半的判断一个道理，所以不做
- 因此 `theme.source` 即使写在 Nix 里，**首次也需在 GUI 选一次**，或跑：

  ```bash
  noctalia msg color-scheme-set custom mactahoe
  noctalia msg color-scheme-get        # 应回：custom mactahoe
  ```

  若调色板文件有问题，noctalia 会在日志里报 `custom palette 'mactahoe' not found or invalid; falling back to builtin`。

### 调色板取值为何不用社区方案 ADW

社区调色板 ADW 的 `mSurface` 恰好也是 `#242424`，但其余色槽映射有误，故重做：

| 色槽 | ADW | 问题 | 本仓库取值 |
|---|---|---|---|
| `mOnSurfaceVariant` | `#ffffff` | 与 `mOnSurface` 相同 → **没有文字层级** | `#afafaf`（MacTahoe 次级前景） |
| `mSecondary` | `#1b467c` | 暗海军蓝，在 `#242424` 上几乎看不见 | `#2e7cf7`（同族第二蓝） |
| `mTertiary` | `#ffffff` | 纯白当强调色，且与文字色重复 | `#4dacff`（同族亮蓝） |
| `mPrimary` | `#3584e4` | GNOME 蓝，不是壳层强调色 | `#0088ff` |
| `mHover` | `#3584e4` | 饱和强调色当悬浮底色（文档约定是柔和提亮） | `#3d3d3d`（唯一插值项） |
| `mSurfaceVariant` | `#1e1e1e` | 比主面更暗，层叠方向反了 | `#333333` |
| `mOnSurface` | `#ffffff` | 比 MacTahoe 的 `#dedede` 刺眼 | `#dedede` |
| `mOutline` | `#3d3846` | 紫调灰，与中性壳层不同族 | `#454545`（= MacTahoe 的 `rgba(255,255,255,.15)` 发丝边合成值） |

### 终端色槽（`terminal`）

调色板的每个色块还带一个 `terminal` 子表（16 色 + 前景/背景/光标/选区），供 Noctalia 渲染
终端类模板使用。暗色块 = Catppuccin **Frappe**，亮色块 = Catppuccin **Latte**，语义槽位对齐
暗色那份（详见「双层配色模型」）：`foreground = text`、`cursor = rosewater`、选区 = `mauve`。
**两个色块都必须显式填**，理由见「双层配色模型」的说明（缺了会被推导成错色相）。

### bar 收敛（GUI 侧执行，一次性步骤）

当前 19 个控件、`background_opacity = 0.15`。以应用层为主体后应当退到背景，但不是退回隐形。

**透明度是可算的，不该拍脑袋。** 合成永远是“`opacity` × 底色 + (1−`opacity`) × 模糊后的壁纸”。壁纸默认集纳管之后（见下节）这个输入是**已知**的，于是按两个默认壁纸各自的**屏顶 5% 均值**（bar 背后亮度的上界，模糊只会把它拉低）算：

| opacity | `city-street`（73.4） | `ocean-waves`（120.7） |
|---|---|---|
| 0.15（原值） | `#444444` 7.24:1 ✅ | `#6C6C6C` 3.90:1 ⚠️ |
| 0.25 | 7.71:1 ✅ | 4.40:1 ⚠️ |
| **0.30（取）** | **7.95:1** ✅ | **4.75:1** ✅ |
| 0.35 | 8.20:1 ✅ | 5.05:1 ✅ |
| 0.80（旧“目标”） | 10.52:1 ✅ | 9.12:1 ✅ |

取 **0.30**：两个默认壁纸下都过 AA，同时还是玻璃而不是板子。0.15 在 `ocean-waves` 下只有 3.90:1——默认集里有一张会让 bar 的字变糊；0.25 差一点（4.40）；而 0.80 是“壁纸是自由变量”时代按最坏情况推出来的，现在既没必要也不好看。

（终端 `opacity 0.85` 维持不变：用 16×16 分块的最亮块当背后最坏情况，0.80 只到 4.8:1，0.85 是 5.5:1。表在 `frosted-glass.kdl`。）

控件 19 → 8：

| 位置 | 现状 | 留 | 理由 |
|---|---|---|---|
| `end`（12 → 6） | launcher, deepseek_usage, activity, cat, tray, clipboard, notifications, bluetooth, brightness, volume, theme_mode, session | tray, clipboard, notifications, volume, brightness, session | 两个第三方信息流（DeepSeek 用量、GitHub 动态）与猫占的是最右端的视觉焦点 |
| `center`（4 → 1） | capsule(media+audio_visualizer), date, todo, notes | date | 音频可视化 + 待办/便签属于“盯着看”的内容，与应用层争焦 |
| `start`（3 → 1） | workspaces, keymap, w-engine | workspaces | 键盘布局切换很少用 |
| `widget.cat.rave_mode` | `true` | `false` | 动画在静止的壳层里是持续噪音；只能在 GUI 里关，原因见下方执行方式 |

**执行方式**：四项（`bar.default` 的 `background_opacity`/`start`/`center`/`end`）已声明在 `programs.noctalia.settings` —— 它们没有密钥，可以纳管。但运行时状态优先，已有 state 的主机要把 state 里那四行删一次才会生效，见 `docs/manager.md` 的「装机后的一次性步骤」。bar 其余的键（`capsule` / `enabled` / `margin_edge` …）仍归 GUI；表里的 `rave_mode` 也是 GUI 侧关（小部件的 id/type 归 GUI，只声明子键会被 validate 判为 “unrecognized widget type”）。

### 壁纸：默认集纳管，可覆盖

`assets/wallpapers/` 放默认集（`city-street.jpg`、`ocean-waves.jpg`），由
`mySystem.desktop.wallpapers` 声明 —— **首项即默认壁纸**（与 `monitors` 首项派生
`scale` 同一约定）。两处消费同一份声明：

| 消费者 | 用哪条路径 | 为什么 |
|---|---|---|
| Noctalia（桌面会话） | `~/Pictures/wallpaper/默认集/<名>` | 面板会把选中的路径写进 `settings.toml`，写 store 路径会在 rebuild 后指向一个可能已被 GC 的旧 hash |
| GDM（登录界面） | store 路径 | greeter 的 systemd 单元受限；store 世界可读且不可变 |

默认集部署成 picker 浏览根（`~/Pictures/wallpaper/`）下的**子目录**：用户自己的图仍在同一层可浏览、可选中，换壁纸的流程（`Mod+Alt+W` / 面板）没有任何变化。锁屏不需要单独配：`lockscreen.wallpaper` 留空即“跟随桌面壁纸”。

**为何改掉原来的“有意不纳管”**：透明度、模糊饱和度、焦点环对比度三处取值都建立在“壁纸是自由变量、按最坏情况定”这个前提上；而那个最坏情况不是假想的——近纯白的图就真实躺在 `~/Pictures/wallpaper/` 里。把默认集换成已知底色后，前提从“最坏情况”变成“已知情况”，这些约束才可以重算，而不是防御性拉高。

选图准则（配合 `saturation 1.10`）：大面积暗部、低彩度、少高频细节。实测（YAVG 亮度 / SATAVG 饱和度，0–255）：

| 图 | 分辨率 | YAVG | SATAVG |
|---|---|---|---|
| `city-street`（默认） | 5120×2880 | 44.8 | 2.4 |
| `ocean-waves` | 5434×3053 | 85.4 | 8.9 |

bar 文字（`#DEDEDE`）的对比度，背景取**屏顶 5% 均值**（bar 背后亮度的上界，模糊会把它拉向局部均值）：

| 壁纸（屏顶均值） | opacity 0.15 | 0.50 | 0.80 |
|---|---|---|---|
| `city-street`（73.4） | **7.24:1** ✅ | 8.85:1 | 10.52:1 |
| `ocean-waves`（120.7） | 3.90:1 ⚠️ | 6.19:1 ✅ | 9.12:1 |

一次性步骤（已经选过壁纸的主机）：`noctalia msg wallpaper-set <path>` 会把所有输出与 `wallpaper.default.path` 一起写进 `settings.toml`。只改 Nix 声明不会生效——运行时状态优先（同 `theme.source` 那条）。把图丢进 `~/Pictures/wallpaper/` 即在面板里可选。

### 不认领的三个面（写下来的决定）

有些像素不属于这套设计语言。逐一查明后**明确不认领**，免得以后重复怀疑：

- **锁屏**：已经一致，无需配置。Noctalia 的 `settings.toml` 里**没有** `[lockscreen]` 段，即全默认：`wallpaper = ""`（跟随桌面壁纸）、`blur_intensity 0.5`、`tint_intensity 0.3`。锁屏上的部件位置（登录框等）归 GUI，存在 `lockscreen_widgets` 里。
- **niri 自绘的浮层**（快捷键 overlay、截图 UI、退出确认对话框）：**配不了**。实测 `hotkey-overlay {}` / `screenshot-ui {}` / `ui {}` 三个节点都被 `niri validate` 拒绝——niri 的配置里没有给它们的颜色入口。它们的观感是 niri 自己的，改不了，也不必惦记。
- **Windows / RemoteApp 窗口与 Steam 的内部 UI**：只有**外框**是我们的—— 8px 圆角与合成器阴影由 niri 统一绘制，所以它们与其它窗口的框架一致；窗口内部的标题栏、配色、控件全是它们自己的。这是“覆盖不了”，不是“没覆盖”。

（第四个面——GDM 登录界面——是**认领**的：字体 / 图标 / 光标 / 壁纸都声明在 `modules/nixos/desktop/gdm.nix`，与桌面会话共用一套。）

## 相关命令
```bash
# 查看系统级主题
ls /run/current-system/sw/share/themes/

# 光标主题目录（XWayland 应用）
ls ~/.local/share/icons/

# Noctalia 实际在用的调色板、以及调色板载入失败时的回退日志
noctalia msg color-scheme-get
grep -i "falling back to builtin" ~/.cache/noctalia/noctalia.log

# 校验 noctalia 配置（不依赖运行实例）
noctalia config validate ~/.config/noctalia/config.toml
```
