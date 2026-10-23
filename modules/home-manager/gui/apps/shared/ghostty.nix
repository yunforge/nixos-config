# Ghostty 终端配置
#
# 跨平台共享边界：这是「用户配置」层。
#   Linux：程序由 HM 的 programs.ghostty 安装（enable ⇒ home.packages）
#   macOS：程序由 modules/darwin/gui.nix 的 Homebrew cask（`brew install --cask ghostty`）
#          安装，本模块只负责生成 ~/.config/ghostty（settings / 着色器）。
# Ghostty 的包在 nixpkgs 仅支持 Linux（meta.platforms 全是 linux），故 macOS 上
# 不能也不必走 HM 装包——配置同一份，安装方式按平台分开。
#
# 主题：`theme = "noctalia"`，由 Noctalia 统一管理（见 gui/desktop/linux/niri/noctalia.nix
# 的 builtin "ghostty" 模板）。Noctalia 把当前调色板渲染成 ~/.config/ghostty/themes/noctalia，
# 换主题/切亮暗时自动重渲。运行中的窗口不重读配置（ghostty 无外部 reload 入口），
# 新窗口/分屏天然跟随。其它取值（字体、内置着色器、quick terminal、shell 集成等）见各条注释。
{
  lib,
  config,
  pkgs,
  ...
}:
let
  cfg = config.mengw.gui.apps.ghostty;
  guiCfg = config.mengw.gui;
in
{
  options.mengw.gui.apps.ghostty.enable = lib.mkOption {
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
        # 主题由 Noctalia 统一管理（gui/desktop/linux/niri/noctalia.nix 启用 builtin "ghostty" 模板）：
        # Noctalia 把当前调色板渲染成 ~/.config/ghostty/themes/noctalia，其 apply.sh 会把本键
        # 改成 "noctalia"。这里先写好最终值，apply.sh 检测到已是目标值即不写 —— 于是对 HM 的
        # 只读软链没有任何写操作（否则实测报「只读文件系统」）。亮/暗由调色板切换带出。
        # ghostty 无外部 reload 入口，新窗口/分屏天然跟随。
        theme = "noctalia";

        # === 字体与度量 ===
        font-family = [
          "Maple Mono Normal NL NF"
          "LXGW WenKai Mono"
        ];
        font-size = 12;
        # 行间距：+2 像素
        adjust-cell-height = 2;

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
        # 自定义着色器（光标拖尾彩虹 + 粒子），文件在下方 xdg.configFile 里部署
        custom-shader = [
          "~/.config/ghostty/shader/cursor_smear_rainbow.glsl"
          "~/.config/ghostty/shader/party_sparks.glsl"
        ];
        # 让着色器能跑动画循环（否则只在重绘时步进）
        custom-shader-animation = "always";

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
      "ghostty/shader/cursor_smear_rainbow.glsl".source = ./ghostty-shader/cursor_smear_rainbow.glsl;
      "ghostty/shader/party_sparks.glsl".source = ./ghostty-shader/party_sparks.glsl;
    };
  };
}
