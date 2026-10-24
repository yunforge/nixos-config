# Niri 窗口管理器 — 用户级配置文件部署
{
  lib,
  config,
  osConfig,
  pkgs,
  inputs,
  ...
}:
let
  desktopCfg = config.myHome.desktop;
  niriConfigPath = "${config.home.homeDirectory}/Projects/nixos-config/modules/home-manager/gui/desktop/linux/niri/config";

  # ── 概览底色 ────────────────────────────────────────────────────────────
  # niri 装饰颜色现已全部交给 Noctalia（builtin "niri" 模板 → noctalia.kdl），
  # HM 只保留它**不接管**的一项：概览（overview）的工作区底色。
  # 取自 GTK/Qt 侧同一来源 MacTahoe：暗色 view_bg #242424、亮色 view_bg #FFFFFF
  # （share/themes/MacTahoe-{Dark,Light}/gtk-4.0/gtk.css 的 @define-color）。
  shell = {
    backdrop = "#242424";
  };
  shellLight = {
    backdrop = "#FFFFFF";
  };

  # 生成的 layout.kdl：**只留结构**（间距、焦点环宽度、标签指示器几何、阴影参数），
  # 颜色全部删掉 —— 那些键由 noctalia.kdl 提供（niri 合并两个 layout{} 段）。
  # 曾在这里维护的 MacTahoe 取色（焦点环发丝线 / 标签指示器 / 插入提示 / 最近窗口
  # 高亮）连同取舍理由一并移到 Noctalia 调色板的 mPrimary / mError 等语义角色，
  # 见 modules/home-manager/gui/desktop/linux/niri/noctalia.nix 的 customPalettes.mactahoe。
  mkLayout = ''
    // niri 窗口布局配置
    // https://niri-wm.github.io/niri/Configuration%3A-Layout.html
    layout {
        // 窗口之间、以及窗口与屏幕边缘的间距（逻辑像素）。
        // 8 与窗口圆角 8（windowrules.kdl 的 geometry-corner-radius）同档：
        // 间距小于圆角的一半时，相邻两窗的圆角弧比自己半径还靠得近，缝隙看上去
        // 是“被掐住”而不是留白 —— 8 就是圆角 8 时的下限（原来 12 配的是 24）。
        //
        // Omarchy 取 gaps_in 5 / gaps_out 10。要分开就得靠 struts（niri wiki:
        // Layout#struts，正值 = 外间隙），但左右方向的 struts 会让侧边窗口
        // “探头”（niri 文档明说），所以这里只用对称的 gaps。
        gaps 8
        background-color "transparent"  // 工作区透明
        center-focused-column "never"   // 无特殊居中效果
        // 单列工作区居中：有意为之的“专注模式”——一个窗口时留在屏幕中间保持
        // 可读宽度，而不是铺满。想铺满不需要改这项：Mod+F 是 maximize-column，
        // Mod+Minus/Equal 以 5% 为步长手动调列宽。
        always-center-single-column
        // 新窗口的默认列宽（0.5 即 niri 自身的默认值，写明只是为了意图明确）
        default-column-width { proportion 0.5; }

        // 焦点环，用于指示活动窗口
        //
        // 宽度取 1（发丝线语义）：niri 会把逻辑像素按缩放取整到物理像素。
        //   width 1 → desktop 1.5 倍 = 1.5 → 取整 2 物理 ✅ 发丝线
        //              laptop 1.25 倍 = 1.25 → 取整 1 物理（更细，仍是一条线）
        //   width 2 → desktop 3 物理，已经明显粗于发丝线
        //           （laptop 2.5 → 取整 2 或 3）
        // 颜色（active/inactive/urgent）由 noctalia.kdl 提供，见 config.kdl 末尾。
        focus-ring {
            on          // 开启焦点环
            width 1     // desktop 1.5 倍 → 取整 2 物理像素（发丝线）
        }

        // 边框：与焦点环作用重叠，保持关闭，窗口指示只保留焦点环一种
        border {
            off
        }

        // 标签指示器：仅当列进入 tabbed 显示模式时出现（Mod+W）
        // 颜色（active/inactive/urgent）由 noctalia.kdl 提供。
        tab-indicator {
            on
            place-within-column // 指示器绘制列内部
            gap 5 // 指示器与窗口边缘间距
            width 3 // 指示器宽度
            length total-proportion=1.0 // 指示器长度占列总高度比例
            position "right" // 指示器在列的右侧
            gaps-between-tabs 2 // 多个标签指示器并排时间距
            // 指示器宽度 3px，半径 2 ≥ 半宽 ⇒ 两端仍是胶囊（“药丸”语义），
            // 同时不超过窗口圆角 8 —— 内层不会比外层更圆。
            corner-radius 2 // 指示器圆角半径
        }

        // 窗口插入提升：颜色由 noctalia.kdl 提供。
        insert-hint {
            on
        }

        // 阴影：由合成器统一提供。
        //
        // 这不是“叠加”第二层阴影。niri 文档明说：设了 prefer-no-csd 与/或
        // geometry-corner-radius 之后，"These will also remove client-side
        // shadows if the window draws any" —— clip-to-geometry 裁的是
        // xdg_surface 的 window geometry（不含阴影边距），所以 CSD 自绘阴影
        // 已整层消失，这里是唯一的一层。
        // 也因此所有窗口（GTK / Electron / X11）共用同一套阴影，与 macOS 一致；
        // 而且窗口无论响应 prefer-no-csd 与否，结论都一样：
        //   GTK 保留 CSD → 自绘阴影被裁，合成器补上
        //   GTK 放弃 CSD → 本来就没有自绘阴影，合成器提供
        //
        // draw-behind-window 保持默认的 false：文档说因为 niri 不知道 CSD 圆角
        // 才需要 true 来遮住方形角的伪影；而我们给了 geometry-corner-radius，
        // niri 自己知道圆角，不需要“画到窗口后面”，也就不会在半透明窗口
        // （ghostty 0.85）里透出一圈暗影。
        //
        // 取值由 MacTahoe 自己的 CSD 阴影反推（gtk-4.0/gtk.css 的 window.csd）：
        //     0  3px  6px rgba(0,0,0,.15)
        //     0  7px 24px rgba(0,0,0,.12)
        //     0 12px 32px rgba(0,0,0,.08)
        //     0 0 0 2px rgba(0,0,0,.03) / 0 0 0 1px rgba(0,0,0,.12)  ← 两层“环”
        // 单层阴影无法复现三层叠加，所以：
        //   softness 32  = 最大 blur，用以匹配最远的衰减尾
        //   offset y=7   = 三层偏移 3/7/12 按各自 alpha 加权的中值
        //   spread 0     = 三层模糊层的 spread 都是 0
        //   color ≈ 35%  = 三层在窗沿处叠加后的等效不透明度
        // 那两层 0-blur 的“环”不另设 spread：它们等价于一条硬边，
        // 而主题的 outline（rgba(255,255,255,.15) 发丝边）已经在做这件事。
        // 不设 inactive-color：默认按更透明的 color 画，非焦点窗口阴影自动变淡。
        shadow {
            on
            softness 32
            spread 0
            offset x=0 y=7
            color "#00000059"
        }
    }
  '';

  # 生成的 overview.kdl；backdrop 是 Noctalia 不管、HM 仍按亮/暗两态生成的颜色
  mkOverview = backdrop: ''
    // 概览
    overview {
        // 0.50：文字可读，保留一定信息量，兼顾全局视野
        zoom 0.50
        // 概览里工作区背后、以及切换工作区时露出的底色。
        // 注意 niri 会**忽略此色的 alpha 通道**（niri wiki: Configuration:
        // Miscellaneous），所以这里只能给不透明色，写成 #242424cc 无效。
        // 用中性深/浅色，避免一大片中饱和色与窗口的冷调内容色温相反（缩略图"糊在泥里"）。
        backdrop-color "${backdrop}"
    }

    // 带缩略图的 Super+Tab 窗口切换器
    recent-windows {
        debounce-ms 750
        open-delay-ms 150

        highlight {
            // 焦点预览的高亮框的颜色由 noctalia.kdl 提供。
            padding 30
            // 8：与窗口圆角同档（按阶梯取 ≤ 窗口圆角）
            corner-radius 8
        }

        previews {
            max-height 480
            max-scale 0.2
        }

        binds {
            Mod+Tab         { next-window scope="workspace"; }
            Mod+Shift+Tab   { previous-window scope="workspace"; }
            Mod+grave       { next-window     filter="app-id"; }
            Mod+Shift+grave { previous-window filter="app-id"; }
        }
    }
  '';

  # 生成的 outputs.kdl —— 由主机声明的 mySystem.desktop.monitors 数据驱动
  # （hosts/<host>/default.nix）：本模块只做生成器，显示器数据留在主机。
  # niri 的 output 段按物理输出名匹配，未连接的输出条目会静默失效，
  # 故每台主机只声明自己实际连接的屏幕。
  outputsKdl =
    let
      monitors = osConfig.mySystem.desktop.monitors;
      monitorKdl =
        m:
        let
          # toJSON 而非 toString：新版 Nix 的 toString 对 float 固定输出 6 位
          # 小数（1.5 → "1.500000"），KDL 虽能解析但可读性差；toJSON 给最短表示
          scaleStr = builtins.toJSON m.scale;
        in
        lib.concatStringsSep "\n" (
          [ "output \"${m.name}\" {" ]
          ++ lib.optionals (m.mode != null) [ "    mode \"${m.mode}\"" ]
          ++ [ "    scale ${scaleStr}" ]
          ++ [ "}" ]
        );
    in
    if monitors == [ ] then
      throw "myHome.gui.wm: 主机未声明 mySystem.desktop.monitors，无法生成 niri outputs.kdl"
    else
      lib.concatMapStringsSep "\n" monitorKdl monitors;

  # Ctrl+Alt+Del 关闭全部窗口
  # niri 只有作用于焦点窗口的 close-window，没有"关闭全部"动作：这里先快照
  # 当前所有窗口 id，再逐个 focus-window + close-window。逐个关闭而非 kill
  # 进程，是为了让应用走自己的关闭流程（弹"未保存"确认、落盘配置等）。
  # 只遍历一次快照：遇到卡在确认对话框关不掉的窗口就停下，不会死循环。
  niriCloseAll = pkgs.writeShellScriptBin "niri-close-all" ''
    set -u
    ${pkgs.jq}/bin/jq -r '.[].id' \
      < <(${pkgs.niri}/bin/niri msg -j windows 2>/dev/null) \
      | while read -r id; do
          ${pkgs.niri}/bin/niri msg action focus-window "$id" >/dev/null 2>&1 || continue
          ${pkgs.niri}/bin/niri msg action close-window    >/dev/null 2>&1
        done
  '';

in
{
  imports = [
    ./noctalia.nix
  ];

  # 门控：myHome.desktop.enable 控制整个桌面会话层，无中间层开关
  config = lib.mkIf desktopCfg.enable {
    # Symlink 整个 Niri 配置目录到 git 仓库（保持可编辑性）
    xdg.configFile."niri".source = config.lib.file.mkOutOfStoreSymlink niriConfigPath;

    # 配色文件部署到独立目录（不能放在 niri/ 下，因为
    # ~/.config/niri 是 symlink 指向 $HOME 外的 git 仓库）。
    # 注意：config.kdl 中使用 ~/.config/niri-colors/ 绝对路径而非
    # ../niri-colors/ 相对路径，因为 niri 解析 include 时会跟随
    # symlink 链，导致 .. 解析到 git 仓库父目录而非 ~/.config/。
    # outputs.kdl 同理：按主机区分的内容也无法放进被 symlink 的共享目录。
    #
    # layout.kdl 现在与亮/暗无关（只剩结构），直接由 HM 持有，不进 theme-apply。
    # force：仍需要 —— 老机器的这个软链正指向 theme-apply 的变体（layout-light.kdl），
    # 不带 force 的话 HM 的 checkLinkTargets 会判成外来文件、整份激活失败。
    xdg.configFile."niri-colors/layout.kdl".text = mkLayout;
    xdg.configFile."niri-colors/layout.kdl".force = true;
    # overview.kdl 仍随亮/暗切换（概览底色），故走 theme-apply 的软链机制。
    # force：这个软链归 theme-apply 运行时接管（light 模式会指到 light 变体），
    # 而 HM 的 checkLinkTargets 只认「指向本 generation」的软链，指到变体就判成
    # 外来文件「would be clobbered」而整个激活失败。force 只跳过碰撞检查，
    # HM 仍会把自己那份先按普通软链铺好（= 初始暗色）。
    xdg.configFile."niri-colors/overview.kdl".text = mkOverview shell.backdrop;
    xdg.configFile."niri-colors/overview.kdl".force = true;
    xdg.configFile."niri-outputs/outputs.kdl".text = outputsKdl;

    # overview 的亮/暗两套也各生成一份到 store：运行时由 theme-apply 把上面的软链
    # 指过来（见 gui/themes/variants.nix，那里是唯一的切换入口）
    xdg.configFile = {
      "theme-variants/niri/overview-dark.kdl".text = mkOverview shell.backdrop;
      "theme-variants/niri/overview-light.kdl".text = mkOverview shellLight.backdrop;
    };

    home.packages = [
      niriCloseAll
    ];
  };
}
