# Noctalia Shell 用户级配置
#
# 不 import 上游 flake 的 homeModules.default：home-manager 自带 programs.noctalia
# （选项集与上游模块相同，且多出 calendar 账户集成）。上游模块里的
# `disabledModules = [ "programs/noctalia.nix" ]` 只对旧文件名生效，HM 把该模块改成
# programs/noctalia/default.nix 后失效，两者同声明 → 求值报 "already declared"。
{
  lib,
  config,
  osConfig,
  myLib,
  ...
}:
let
  cfg = config.myHome.gui.wm.noctalia;
  desktopCfg = config.myHome.desktop;

  # DDC/CI 亮度：由主机声明的 mySystem.desktop.monitors 中 ddc = true 的输出
  # 派生（desktop 两块外接屏均已开启；需硬件支持且主机已开 hardware.i2c）。
  # 内屏 eDP 走 sysfs backlight；在不支持的主机上 enable_ddcutil 只会让
  # noctalia 反复跑必然失败的 ddcutil detect。
  ddcMonitors = lib.filter (m: m.ddc) osConfig.mySystem.desktop.monitors;
  useDdc = ddcMonitors != [ ];

  # 状态栏按输出开关：主机在 mySystem.desktop.monitors 里用 bar = false 标记
  # 不要状态栏的输出。Noctalia 的 bar 默认在**每块**连着的屏上都生成一份实例
  # （见上游 Bar 文档 "Each bar is spawned on every connected monitor"），
  # 唯一的逐屏开关是 [bar.<name>.monitor.<match>] 的 enabled = false。
  #
  # match 走"连接名精确匹配"（上游 outputMatchesSelector：先比 connector name，
  # 再在描述/make/model/serial 里做整词匹配），故直接用 m.name 原样作 match：
  # DP-2 精确命中自己，不会被 DP-3 的描述误伤。
  #
  # 这段是 Nix 侧独有的表：运行时 state 的 [bar.default] 只有标量键，
  # 不会遮蔽它（Noctalia 合并 config.toml 与 state 时表是逐键深合并）。
  barlessMonitors = lib.filter (m: !m.bar) osConfig.mySystem.desktop.monitors;

  # ── 壁纸 ──────────────────────────────────────────────────────────────
  # 默认集来自系统层 mySystem.desktop.wallpapers（首项为默认壁纸），部署到
  # picker 浏览根下的独立子目录：与用户自己的图分开，同时仍是面板里可浏览的
  # 一层（面板把子目录列成条目）。
  #
  # "Pictures/wallpaper" 是相对形式：home.file 的键必须相对 $HOME，而面板要
  # 绝对路径，两者同源避免写两遍。
  wallpaperRootRel = "Pictures/wallpaper";
  wallpaperRoot = "${config.home.homeDirectory}/${wallpaperRootRel}";
  wallpaperSetRel = "${wallpaperRootRel}/默认集";
  wallpaperSet = "${config.home.homeDirectory}/${wallpaperSetRel}";
  wallpapers = osConfig.mySystem.desktop.wallpapers;

  # 发布后的真实路径，不是 store 路径：面板选中的路径会被写进 settings.toml，
  # 写 store 路径会在 rebuild 后指向一个可能已被 GC 的旧 hash。
  defaultWallpaper =
    if wallpapers == [ ] then
      throw "myHome.gui.wm.noctalia：mySystem.desktop.wallpapers 为空，无法确定默认壁纸"
    else
      "${wallpaperSet}/${baseNameOf (lib.head wallpapers)}";
in
{
  options.myHome.gui.wm.noctalia.enable = lib.mkOption {
    type = lib.types.bool;
    default = true;
    description = "启用 Noctalia Shell 用户级配置";
  };

  config = lib.mkIf (cfg.enable && desktopCfg.enable) {
    # 默认壁纸集部署进 picker 目录（见上方 wallpaperSet）
    home.file = lib.listToAttrs (
      map (w: lib.nameValuePair "${wallpaperSetRel}/${baseNameOf w}" { source = w; }) wallpapers
    );

    # 本仓库自带的 Noctalia 用户模板（上游没有 eza / fish）。
    # 放在 ~/.config/noctalia/templates/ 下：Noctalia 的 input_path 相对配置目录解析，
    # template 的注册见下方 settings.theme.templates.user。
    xdg.configFile = {
      "noctalia/templates/eza.yml".source = ../themes/noctalia-templates/eza.yml;
      "noctalia/templates/fish.fish".source = ../themes/noctalia-templates/fish.fish;
    };

    programs.noctalia = {
      enable = true;

      # ⚠️ 这里的 settings 只是**出厂默认值**：GUI 里的改动会写进
      # ~/.local/state/noctalia/settings.toml（运行时状态），并覆盖本文件对应键。
      # 模块文档原话："these settings can still be overwritten at runtime via the
      # settings menu"。故 bar 的布局（控件列表、胶囊、透明度）与插件配置不在此
      # 维护，那部分归 GUI；本模块只负责需要在版本控制里钉死的东西：调色板。
      # 实测被运行时覆盖的键见 docs/themes.md 的"Noctalia"一节。
      settings = {
        shell = {
          font_family = lib.mkForce myLib.theme.fontSans;
        };
        theme = {
          mode = "dark";
          # 用下面的自定义调色板，而不是内置/社区方案：只有自定义调色板能同时钉住
          # "MacTahoe 的中性灰"与"#0088FF 强调色"。
          # 注意：若 settings.toml 已有 theme.source，本项会被它覆盖，改后需在
          # Noctalia 外观面板选中一次，或跑
          #   noctalia msg color-scheme-set custom mactahoe
          source = lib.mkForce "custom";
          custom_palette = lib.mkForce "mactahoe";

          # 模板：Noctalia 是配色的唯一真源，它按当前调色板渲染各应用的主题文件。
          # 各应用的主配置里已写好最终值（ghostty theme = "noctalia"、btop color_theme
          # = "noctalia"、yazi [flavor] = noctalia），所以模板的 apply.sh 检测到已是
          # 目标值即不写，不会去动那些 HM 只读软链。
          #
          # ⚠️ 运行时 ~/.local/state/noctalia/settings.toml 里若已有 [theme.templates]
          # 段，会**覆盖**这里（与上面 bar.default 同一个坑）。首次生效需把运行时那段
          # 删一次再 `noctalia msg config-reload`；之后归本模块管。
          templates = {
            # 只列本仓库实际用的：gtk3/gtk4/qt 故意不启用 —— GTK/Qt 保持
            # MacTahoe（自打包完整主题），见 docs/themes.md。starship 本机没装也不在
            # 配置里，故不列。
            builtin_ids = [
              "btop"
              "ghostty"
              "niri" # niri 窗口装饰跟随（写 ~/.config/niri/noctalia.kdl）
            ];
            # 社区模板只启用实测安全的：yazi 的 apply.sh 把 [flavor] 改成 noctalia，
            # 主配置里已是该值 → 不写。其它社区模板（fastfetch/bat/…）的 apply.sh 可能
            # 改写 HM 只读的配置文件，逐个核实后再加，见 docs/themes.md。
            community_ids = [ "yazi" ];
            # 上游没有 eza / fish 模板，用本仓库自带的用户模板补上（见下方
            # noctalia/templates/ 的部署）。input_path 相对 ~/.config/noctalia/ 解析。
            user = {
              eza = {
                input_path = "templates/eza.yml";
                output_path = "$XDG_CONFIG_HOME/eza/theme.yml";
              };
              fish = {
                input_path = "templates/fish.fish";
                output_path = "$XDG_CONFIG_HOME/fish/conf.d/noctalia-colors.fish";
              };
            };
          };
        };
        wallpaper = {
          # picker 面板按此目录列图，不写则回落到 XDG Pictures（多一层目录）
          directory = wallpaperRoot;
          # 默认壁纸：新机器或状态里没有选择时生效。已有选择的主机要让它生效，
          # 跑一次 noctalia msg wallpaper-set <path>（见 docs/manager.md）
          default.path = defaultWallpaper;
        };
        # bar 布局：这四项可以声明式 —— 它们没有密钥（明文 API key 在 state 的
        # [plugin_settings."coder/deepseek_usage"] 段里，与本组无关）。bar 的其余键
        # （capsule / enabled / margin_edge / members …）仍归 GUI，本模块只钉这四项。
        # 取值理由与对比度算据见 docs/themes.md 的「bar 收敛」。
        # 注意：运行时 state 里已有同键会遮蔽这里，首次生效需把 state 那四行删一次
        # （见 docs/manager.md）。
        bar.default = {
          background_opacity = 0.30;
          start = [ "workspaces" ];
          center = [ "date" ];
          end = [
            "tray"
            "clipboard"
            "notifications"
            "volume"
            "brightness"
            "session"
          ];
          # 逐屏覆盖：主机声明 bar = false 的输出在这里被关掉状态栏
          # （desktop 的 24" DP-2）。表名为输出名，match 同名。
          monitor = lib.mkIf (barlessMonitors != [ ]) (
            lib.listToAttrs (
              map (
                m:
                lib.nameValuePair m.name {
                  match = m.name;
                  enabled = false;
                }
              ) barlessMonitors
            )
          );
        };
        # 不写 widget.cat.rave_mode：小部件本身（其 id 与 type）由 GUI 持有，
        # 只声明它的一个子键会在 config.toml 里生成一个无 type 的 [widget.cat] 段，
        # noctalia config validate 会报 `unrecognized widget type "cat"`。
        # 关掉 rave 动画改为 GUI 侧一次性步骤（见 docs/manager.md）。
        brightness = {
          enable_ddcutil = useDdc;
          # 每个声明了 ddc = true 的输出各生成一条 ddcutil 后端映射
          monitor = lib.mkIf useDdc (
            lib.listToAttrs (map (m: lib.nameValuePair m.name { backend = "ddcutil"; }) ddcMonitors)
          );
        };
        audio = {
          # 不写 enable：noctalia 1.0 的配置校验把它判为 "unknown setting"
          # （noctalia config validate 实测报 audio.enable: unknown setting）
          enable_overdrive = true;
          enable_sounds = false;
          # 不写 sound_volume / volume_change_sound / notification_sound：
          # 这三个键服务的功能已被 enable_sounds = false 关掉，留着就是服务死功能的
          # 旋钮（以后开音效时 GUI 会自己把音量写进 settings.toml）。
          # 注意上面两个也是“出厂默认”而非“本机现状”：本机 settings.toml 里有自己
          # 的值且优先生效，约定见 docs/themes.md 的「Noctalia：调色板归 Nix」一节。
        };
      };

      # 壳层调色板：与 GTK / Qt / niri 装饰同源，全部取自 MacTahoe-Dark 的
      # share/themes/MacTahoe-Dark/gtk-4.0/gtk.css（括号内是该色在 CSS 里的出现次数）。
      #
      # 为什么不直接用社区方案的 ADW：它的 mSurface 恰好也是 #242424，但
      #   mOnSurfaceVariant = mOnSurface = #ffffff   → 没有文字层级
      #   mSecondary = #1b467c                        → 暗海军蓝，在 #242424 上几乎不可见
      #   mTertiary = #ffffff                         → 纯白当强调色，且与文字色重复
      #   mPrimary = #3584e4                          → GNOME 蓝，不是壳层的 #0088FF
      #   mHover = #3584e4                            → 饱和强调色当悬浮底色（文档约定是柔和提亮）
      #   mSurfaceVariant = #1e1e1e                   → 比主面更暗，层叠方向反了
      #
      # 不写 light 变体：文档规定省略时两种模式都用 dark，而桌面是纯深色。
      customPalettes.mactahoe = {
        dark = {
          mPrimary = "#0088FF"; # 主强调色 (106)
          mOnPrimary = "#FFFFFF";
          mSecondary = "#2E7CF7"; # 同族第二蓝（按下/深色态）(12)
          mOnSecondary = "#FFFFFF";
          mTertiary = "#4DACFF"; # 同族亮蓝，供渐变中段 (6)
          mOnTertiary = "#242424";
          mError = "#ED5F5D"; # 与 niri 的 urgent-color 同源 (29)
          mOnError = "#FFFFFF";
          mSurface = "#242424"; # 主面 (73)
          mOnSurface = "#DEDEDE"; # 主文字 (95)
          mSurfaceVariant = "#333333"; # 次级面：卡片 / 胶囊底 (54)
          mOnSurfaceVariant = "#AFAFAF"; # 次级文字 (13)
          # = MacTahoe 给窗口的 rgba(255,255,255,0.15) 发丝边压在 #242424 上的
          #   合成值，也就是它自家的"玻璃边缘高光"
          mOutline = "#454545";
          # 唯一插值项：MacTahoe 只提供 #242424 与 #333333 两级灰，而悬浮态必须与
          # 主面、次级面都能区分，故取两者之间
          mHover = "#3D3D3D";
          mOnHover = "#FFFFFF";
          mShadow = "#000000";

          # 终端色槽属于"工作区"一族而不是壳层。这里就是 Catppuccin Frappe
          # （terminal 模板现在开着，见本文件顶部的 theme.templates）—— Noctalia 按它
          # 渲染 ghostty/btop/yazi 与 eza/fish，故终端配色与本文件同源；
          # 亮色那一份是 Latte（见下面 light 块）。
          terminal = {
            background = "#303446";
            foreground = "#C6D0F5";
            cursor = "#F2D5CF";
            cursorText = "#303446";
            # 选区与 ghostty 同源：mauve（见 docs/themes.md 的「双层配色模型」）
            selectionBg = "#CA9EE6";
            selectionFg = "#303446";
            normal = {
              black = "#51576D";
              red = "#E78284";
              green = "#A6D189";
              yellow = "#E5C890";
              blue = "#8CAAEE";
              magenta = "#F4B8E4";
              cyan = "#81C8BE";
              white = "#B5BFE2";
            };
            bright = {
              black = "#626880";
              red = "#E78284";
              green = "#A6D189";
              yellow = "#E5C890";
              blue = "#8CAAEE";
              magenta = "#F4B8E4";
              cyan = "#81C8BE";
              white = "#A5ADCE";
            };
          };
        };

        # 亮色：角色映射与 GTK 侧同源，取自 MacTahoe-Light/gtk-4.0/gtk.css 的 @define-color
        # （view_bg #ffffff / window_bg #f5f5f5 / window_fg #363636 / headerbar_fg #575757；
        #  强调色与错误色两态同色：accent_bg #0088FF、destructive_bg #ED5F5D）。
        # 两个推导值沿用暗色那份的口径：
        #   mOutline = MacTahoe-Light 的发丝边 rgba(0,0,0,0.12) 压在 #FFFFFF 上
        #   mHover   = 它自带的 shade rgba(0,0,0,0.07) 压在 #FFFFFF 上
        light = {
          mPrimary = "#0088FF";
          mOnPrimary = "#FFFFFF";
          mSecondary = "#2E7CF7";
          mOnSecondary = "#FFFFFF";
          mTertiary = "#4DACFF";
          mOnTertiary = "#FFFFFF";
          mError = "#ED5F5D";
          mOnError = "#FFFFFF";
          mSurface = "#FFFFFF";
          mOnSurface = "#363636";
          mSurfaceVariant = "#F5F5F5";
          mOnSurfaceVariant = "#575757";
          mOutline = "#E0E0E0";
          mHover = "#EDEDED";
          mOnHover = "#242424";
          mShadow = "#000000";
          # 终端 16 色：亮色态用 Catppuccin **Latte**（暗色态那份是 Frappe）。
          # 必须显式填：Noctalia 渲染终端类模板时，若当前模式的色块没有 terminal，
          # 它会**自行推导**一套，而推导结果色相是错的
          # （实测 mactahoe 只填 dark.terminal 时，亮色渲染出 palette2 = #0076df —— 绿色槽给成蓝色）。
          # 取值 = 上游 Latte 调色板（catppuccin/palette）。语义槽位对齐与 Frappe 那份一致：
          #   foreground=text, cursor=rosewater, selection=mauve（见 docs/themes.md「双层配色模型」）。
          terminal = {
            background = "#EFF1F5";
            foreground = "#4C4F69";
            cursor = "#DC8A78";
            cursorText = "#EFF1F5";
            selectionBg = "#8839EF";
            selectionFg = "#EFF1F5";
            normal = {
              black = "#5C5F77";
              red = "#D20F39";
              green = "#40A02B";
              yellow = "#DF8E1D";
              blue = "#1E66F5";
              magenta = "#EA76CB";
              cyan = "#179299";
              white = "#ACB0BE";
            };
            bright = {
              black = "#6C6F85";
              red = "#D20F39";
              green = "#40A02B";
              yellow = "#DF8E1D";
              blue = "#1E66F5";
              magenta = "#EA76CB";
              cyan = "#179299";
              white = "#BCC0CC";
            };
          };
        };
      };
    };
  };
}
