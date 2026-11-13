# Ghostty 终端配置
#
# 跨平台共享边界：这是「用户配置」层。
#   Linux：程序由 HM 的 programs.ghostty 安装（enable ⇒ home.packages）
#   macOS：程序由 modules/darwin/gui.nix 的 Homebrew cask（`brew install --cask ghostty`）
#          安装，本模块只负责生成 ~/.config/ghostty（settings / 着色器）。
# Ghostty 的包在 nixpkgs 仅支持 Linux（meta.platforms 全是 linux），故 macOS 上
# 不能也不必走 HM 装包——配置同一份，安装方式按平台分开。
#
# 主题：`theme = "Catppuccin Frappe"`，ghostty 自带、固定暗色。不再由 Noctalia 渲染
# （builtin "ghostty" 模板已在 gui/desktop/linux/niri/noctalia.nix 里摘掉，理由见那里）。
# 运行中的窗口不重读配置（ghostty 无外部 reload 入口），改完按 ctrl+shift+, 或新开窗口。
# 其它取值（字体、内置着色器、quick terminal、shell 集成等）见各条注释。
{
  lib,
  config,
  pkgs,
  ...
}:
let
  cfg = config.myHome.gui.apps.ghostty;
  guiCfg = config.myHome.gui;
in
{
  options.myHome.gui.apps.ghostty.enable = lib.mkOption {
    type = lib.types.bool;
    default = true;
    description = "启用 Ghostty 终端配置（程序本体在 macOS 走 Homebrew cask）";
  };

  config = lib.mkIf (cfg.enable && guiCfg.enable) {
    programs.ghostty = {
      enable = true;
      # nixpkgs 的 ghostty 仅支持 Linux（meta.platforms 全是 linux）。
      # macOS 上程序由 modules/darwin/gui.nix 的 Homebrew cask 安装，
      # package = null 让本模块只生成 ~/.config/ghostty 而不装包——
      # 配置共享，安装方式按平台分开（HM 模块文档推荐的用法）。
      package = lib.mkIf (!pkgs.stdenv.hostPlatform.isLinux) null;
      settings = {
        # 固定暗色主题，ghostty 自带。与仓库工作区一族（Catppuccin Frappe）同源：
        # Noctalia 调色板的 dark.terminal 色槽填的就是这套 16 色。
        # 不再由 Noctalia 的 builtin "ghostty" 模板渲染 —— 那会把本键改写回 "noctalia"
        # （对 HM 只读软链报「只读文件系统」，且默认会话切到 Plasma 后 Noctalia 不在跑，
        # 渲染出的主题文件会停在旧模式上）。故模板已从 noctalia.nix 的 builtin_ids 摘除。
        theme = "Catppuccin Frappe";

        # === 字体与度量 ===
        font-family = [
          "Maple Mono Normal NL NF"
          "LXGW WenKai Mono"
        ];
        font-size = 12;
        # 行间距：+2 像素
        adjust-cell-height = 2;

        # Ghostty 用自己的 FreeType 加载标志，**不读 fontconfig 的 hinting 设置**
        # （实测：系统侧 hintstyle=none 时终端字形仍被 hint）。默认值是
        # `hinting,no-force-autohint,no-monochrome,autohint,light`，即 hinting 开、
        # autohint 也开。
        #
        # 这与字体选型直接矛盾：fonts.packages 里的 Maple Mono 特意选了
        # **-unhinted** 构建（见 modules/nixos/core/locale.nix 的注释），而 autohint
        # 正是「对没有自带 hinting 的字体生效」的开关 —— 等于把那份刻意不 hinting
        # 的轮廓重新对齐一遍。这里全部关掉，与桌面其余部分的灰度 + 不 hinting 对齐。
        #
        # 只影响 Linux：macOS 构建走 CoreText，ghostty 文档明确该键对 macOS 无效，
        # 故不按平台分支（写了也无副作用）。
        freetype-load-flags = "no-hinting,no-force-autohint,no-monochrome,no-autohint,no-light";

        # 背景保持不透明（1.0）：半透明与模糊都交给 niri 的 window-rule，见
        # wm/config/visual/frosted-glass.kdl 那条规则的注释（含对比度算据）。
        #
        # 试过另一种做法并量过：ghostty 自己只压背景（background-opacity = 0.80）+
        # niri 侧 opacity 1.0。结果文字确实更清晰，但**玻璃基本看不出来** —— 让玻璃“显形”
        # 的其实是文字连同底色一起透到壁纸上（实测：暗区背后 0.8×#303446 = #2A2E3F，与纯色
        # #303446 几乎无差）；而且 niri 的透明度对**已经开着**的窗口即时生效，ghostty 自己的
        # 配置要重开才生效。故回到 niri 侧整体透明度。
        background-opacity = 1.0;
        # 内边距 x=8 y=6
        window-padding-x = 8;
        window-padding-y = 6;

        # === 光标 ===
        cursor-style = "block";
        cursor-style-blink = true;
        cursor-opacity = 0.8;
        # 自定义着色器：单个「最简单的 Kitty 样式光标拖尾」（残影取光标色、随移动淡出，
        # 无彩虹/无粒子），文件在下方 xdg.configFile 里部署。
        # 动画循环保持默认 true（只动画焦点终端）：always 会让每个 surface 空闲时
        # 也按屏幕刷新率持续跑着色器（desktop 4K@150Hz 实测 3 窗口常驻 ~6% 单核 + GPU），
        # 详见 docs/quirks.md。
        custom-shader = [ "~/.config/ghostty/shader/cursor_trail.glsl" ];

        # === 下拉终端（quick terminal）===
        quick-terminal-position = "top";
        quick-terminal-screen = "mouse";
        quick-terminal-autohide = true;
        quick-terminal-animation-duration = 0.15;

        # === 剪贴板 ===
        clipboard-paste-protection = true;
        clipboard-paste-bracketed-safe = true;
        copy-on-select = "clipboard";
        clipboard-read = "allow";
        clipboard-write = "allow";

        # 输入时隐藏鼠标
        mouse-hide-while-typing = true;

        # === fish 集成 ===
        shell-integration = "fish";
        shell-integration-features = [
          "cursor"
          "sudo"
          "title"
        ];

        # === 其它 ===
        scrollback-limit = 25000000;
        working-directory = "inherit";
        window-save-state = "always";
        # 窗口装饰交给 niri：本仓库走 prefer-no-csd + 自绘圆角/阴影（见 docs/themes.md），
        # 故这里不要 GTK 的完整标题栏，否则会多出一条标题栏。
        window-decoration = "auto";
        gtk-titlebar = false;
        term = "xterm-ghostty";
      }
      // lib.optionalAttrs pkgs.stdenv.hostPlatform.isLinux {
        # 异步 IO 后端改用 epoll（Linux 默认 auto → io_uring；macOS 只有 kqueue，不能设）。
        # 根因见 docs/quirks.md：io_uring 的 io_cqring_wait 把等 timer/poll 的线程记成
        # in_iowait，于是 /proc/stat 的 iowait、procs_blocked 与 PSI io.pressure 被整体
        # 虚高（实测本机 io.pressure 常年 60%+，而设备 %util=0、该 cgroup io.stat 为空）。
        # 后端只换事件循环实现，ghostty 官方文档称两者性能无统计差异。
        async-backend = "epoll";
      };
    };

    xdg.configFile = {
      "ghostty/shader/cursor_trail.glsl".source = ./ghostty-shader/cursor_trail.glsl;
    };
  };
}
