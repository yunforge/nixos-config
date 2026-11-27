# 亮 / 暗两套外观 —— 单一真源是 Noctalia 的 theme mode
# （状态栏那个主题图标切的就是它：noctalia msg theme-mode-toggle）
#
# 为什么需要这一层：主题取值此前全部钉死在 Nix 里（单一深色主题 / 深色调色板），
# 而运行时切换需要**可写的目标文件**，那几个文件都是 HM 的 store 软链
# （gtk-3.0/settings.ini、gtk-4.0/settings.ini、Kvantum/kvantum.kvconfig、
# niri-colors/overview.kdl）。做法：把**两套变体都生成到 store**，脚本只把当前模式对应的
# 软链指过去 —— Nix 仍然持有全部取值，运行时只有一个「哪一套」的选择。
#
# 归属约定（一个文件只有一个主人）：
#   - HM 写初始值（= 亮色，与 noctalia.nix 的 theme.mode 一致）+ 两套变体（~/.config/theme-variants/…）
#   - theme-apply 只做一件事：把上面那几个软链指到当前模式的变体，并写 dconf
#   - 于是 rebuild 后回到亮色，登录时的 theme-apply 再按 Noctalia 的模式纠正，
#     不需要任何「哪套生效中」的状态文件（脚本幂等，见下方 link()）
#
# 为什么监听**目录**而不是文件：Noctalia 保存 settings.toml 是 temp+rename
# （实测 toggle 前后 inode 变了），盯文件的 PathModified 会漏事件；盯目录能抓到 rename。
{
  lib,
  config,
  pkgs,
  myLib,
  ...
}:
let
  cfg = config.myHome.gui.themes;
  desktopCfg = config.myHome.desktop;

  home = config.home.homeDirectory;
  variantDir = "theme-variants";

  # 一套模式的全部取值。改主题只改这里。
  # GTK 变体名取自包里的实际目录：share/themes/{WhiteSur-Dark,WhiteSur-Light}。
  # Kvantum 只被 Plasma 的「应用程序风格」使用，而 Plasma 外观固定为 WhiteSur
  # 浅色（见 kde-appearance.nix），故两套模式都写 WhiteSur：Kvantum 会按应用的
  # QPalette 明暗在同一目录里选 WhiteSur.kvconfig / WhiteSurDark.kvconfig。
  # niri 不设 QT_STYLE_OVERRIDE，Kvantum 的取值对它没有作用。
  # 图标不随亮暗切换：两套都用 WhiteSur-light（KDE 侧同款，见 kde-appearance.nix）。
  modes = {
    dark = {
      gtk = "WhiteSur-Dark";
      icons = "WhiteSur-light";
      kvantum = "WhiteSur";
    };
    light = {
      gtk = "WhiteSur-Light";
      icons = "WhiteSur-light";
      kvantum = "WhiteSur";
    };
  };

  # 窗口按钮在右侧，**左起 最小化 → 最大化 → 关闭**（关闭在最右）。
  # 语法是 `左侧:右侧`（GNOME 约定）；前导冒号表示左侧留空、三个按钮全在右侧。
  # GTK 把右侧列表**按书写顺序从左到右**铺开，故列表即视觉顺序本身。
  #
  # 这条键是全局的唯一入口：除 GTK 外，Chromium / Electron 通过 GTK 的
  # `gtk-decoration-layout` 跟随，Qt（qadwaitadecorations）经 XDG 设置门户读同一个键。
  # 真源是 dconf 的 org.gnome.desktop.wm.preferences button-layout —— GNOME Tweaks 改的
  # 也是它；settings.ini 的同名键会被设置门户盖掉（实测），故不作为真源。
  #
  # 为何按这个顺序：只有 GTK 的 CSD 主题会画 macOS 红黄绿灯，Chromium / Electron / Qt
  # 画的是各自原生符号按钮 —— **位置与顺序是三种框架唯一都能一致表达的东西**，故拿它做
  # 全局对齐的基准。红绿灯下的视觉顺序因此是 黄-绿-红（黄=最小化、绿=最大化、红=关闭）。
  buttonLayout = ":minimize,maximize,close";

  # 与 HM 的 gtk 模块对同一模式写出的内容保持一致（modules/misc/gtk/lib.nix）：
  # gtk-application-prefer-dark-theme 只在暗色出现，gtk-interface-color-scheme 只 GTK4 有。
  gtkIni =
    version: mode:
    let
      m = modes.${mode};
    in
    ''
      [Settings]
      ${
        lib.optionalString (mode == "dark") "gtk-application-prefer-dark-theme=true\n"
      }gtk-cursor-theme-name=${myLib.theme.cursor}
      gtk-cursor-theme-size=24
      gtk-decoration-layout=${buttonLayout}
      gtk-font-name=${myLib.theme.fontSans} 12
      gtk-icon-theme-name=${m.icons}
      ${lib.optionalString (version == 4) "gtk-interface-color-scheme=${mode}\n"}gtk-theme-name=${m.gtk}
    '';

  # 模式无关的 GTK4 用户样式：GTK 只在**启动时读一次**这个文件（GtkCssProvider 文档
  # 原话），所以不能把亮/暗做成两个文件 —— 否则运行中的程序拿到新 color-scheme 后，
  # 里面已经解析进去的还是旧那份调色板（实测：只有一侧变亮）。
  # WhiteSur-GTK 的 gtk-4.0/gtk.css 只是一行 `@import resource:///org/gnome/theme/gtk.css`，
  # 真正的 CSS 与 PNG/SVG 都在同目录的 `gtk.gresource` 里。这里把两套变体的
  # gresource 解包到 store，重写成绝对 file:// URL，再把整份暗色放在顶层、
  # 整份亮色放进 @media(prefers-color-scheme: light)。媒体查询自 GTK 4.20 起
  # 支持（本机 4.22.4），color-scheme 一变就会重算 —— 文件本身永远不需要换。
  #
  # 不能直接用 resource:///org/gnome/theme/...：切换主题时旧 gresource 可能
  # 仍注册着，暗/亮两套的 assets 会串；绝对 file:// 不依赖注册顺序。
  gtk4UserCss =
    pkgs.runCommand "whitesur-gtk-user-css"
      {
        nativeBuildInputs = [ pkgs.glib.dev ]; # gresource
      }
      ''
        theme=${pkgs.whitesur-gtk-theme}/share/themes

        extract() {
          variant="$1"
          case "$variant" in
            Dark) dest="$out/dark" ;;
            Light) dest="$out/light" ;;
          esac
          gresource="$theme/WhiteSur-$variant/gtk-4.0/gtk.gresource"
          mkdir -p "$dest"
          gresource extract "$gresource" /org/gnome/theme/gtk.css > "$dest/gtk.css"
          while IFS= read -r resource; do
            rel="''${resource#/org/gnome/theme/}"
            mkdir -p "$dest/$(dirname "$rel")"
            gresource extract "$gresource" "$resource" > "$dest/$rel"
          done < <(gresource list "$gresource" | grep '^/org/gnome/theme/')
          # 相对 url("assets/…") / url("windows-assets/…") 以**本文件**的 URI 为基准
          # 解析；改成绝对 file:// 后，亮色那份的 PNG 才不会按暗色目录找。
          sed -i -E 's|url\("([a-zA-Z][^":]*)"\)|url("file://'"$dest"'/\1")|g' "$dest/gtk.css"
        }

        extract Dark
        extract Light

        {
          echo '/* 由 Home Manager 生成 —— modules/home-manager/gui/desktop/linux/themes/variants.nix */'
          echo '/* 结构：WhiteSur-Dark；浅色：整份 WhiteSur-Light 覆盖在 @media 里 */'
          cat "$out/dark/gtk.css"
          echo '@media (prefers-color-scheme: light) {'
          cat "$out/light/gtk.css"
          echo '}'

          # 最小化按钮在 niri 上没有对应动作（niri 无 minimize），GTK 把它置为 disabled。
          # GTK 4.x 对 insensitive 控件施加的是 `filter: opacity(.5)`（不是 opacity、
          # 也不是 -gtk-icon-filter —— 那两个属性覆盖后像素完全不变，实测），灯会被压淡。
          # 只认 `filter: none` 一个属性。代价：点它没有反应（动作本就不存在）。
          cat <<'CSS'

        headerbar windowcontrols button.minimize:disabled {
          filter: none;
        }

        /* WhiteSur 的 `switch { font-size: 0 }`：GtkImage 用当前字号算基线，
           ascent+descent 为 0 时除法得 inf，转 int 成 G_MININT，GTK 报
           「baselines ... must be inside」。改成 1px（视觉无差）后警告消失。 */
        switch {
          font-size: 1px;
        }
        CSS
        } > "$out/gtk.css"
      '';

  # GTK4 只认 color-scheme，主题本体靠上面的 import（HM 的 gtk4.theme 就是这么做的）
  kvconfig = mode: ''
    [Applications]

    [General]
    theme=${modes.${mode}.kvantum}
  '';

  variants = {
    "${variantDir}/gtk-3.0/dark.ini".text = gtkIni 3 "dark";
    "${variantDir}/gtk-3.0/light.ini".text = gtkIni 3 "light";
    "${variantDir}/gtk-4.0/dark.ini".text = gtkIni 4 "dark";
    "${variantDir}/gtk-4.0/light.ini".text = gtkIni 4 "light";
    "${variantDir}/kvantum/dark.kvconfig".text = kvconfig "dark";
    "${variantDir}/kvantum/light.kvconfig".text = kvconfig "light";
  };

  applyScript = pkgs.writeShellApplication {
    name = "theme-apply";
    runtimeInputs = [
      pkgs.coreutils
      # 下面用 awk 解析 settings.toml；coreutils 不带 awk，不显式给的话
      # runtimeInputs 造的 PATH 里就没有它，服务里 mode 取空、直接撞 case 退出
      pkgs.gawk
      pkgs.glib # gsettings
      pkgs.dconf # dconf 后端（否则 gsettings 写进内存后端，重启即丢）
    ];
    text = ''
            # 参数可显式给模式（排查用）：theme-apply light
            mode="''${1-}"
            if [ -z "$mode" ]; then
              state="''${XDG_STATE_HOME:-$HOME/.local/state}/noctalia/settings.toml"
              # 先读运行时 state 的 [theme] 段（GUI 切换会把 mode 写在这里）。
              mode="$(awk -F'"' '/^\[/{s=($0=="[theme]")} s && /^mode *=/ {print $2; exit}' "$state" 2>/dev/null)"
              # state 里还没写过 mode（用户从未切换过）时，回落到 HM 生成的
              # config.toml —— 那是版本控制里的默认值（noctalia.nix 的 theme.mode）。
              # 不回落到这里的话 mode 取空串，下面 case 直接报「未知模式」退出，
              # 登录后 GTK/Qt/niri 就停在 HM 初始值不动（实测 theme-apply.service
              # 目前正是因此 failed）。
              if [ -z "$mode" ]; then
                mode="$(awk -F'"' '/^\[/{s=($0=="[theme]")} s && /^mode *=/ {print $2; exit}' "$HOME/.config/noctalia/config.toml" 2>/dev/null)"
              fi
            fi
            case "$mode" in
              light | dark) ;;
              *) echo "theme-apply: 未知模式 '$mode'（取自 Noctalia state），保持现状" >&2; exit 1 ;;
            esac

            # 幂等：已经是这个目标就不动，避免 path 单元每次触发都让 niri 重载。
            # 目标不存在就报错退出：上一次就是把变体路径写少了 .config/，脚本默默把软链
            # 指到不存在的文件，niri 因为 include 读不到而**整份配置拒绝加载**，
            # 现象却是「某些改动没生效」，很难往这里想。
            link() {
              if [ ! -e "$2" ]; then
                echo "theme-apply: 变体不存在：$2（登记的目标路径写错了？）" >&2
                exit 1
              fi
              [ "$(readlink "$1" 2>/dev/null)" = "$2" ] || ln -sfn "$2" "$1"
            }

            # 本模块自己那四个 + 各层登记进来的（fastfetch / nvim）：case 同时把模式相关的
            # 取值（dconf 的 scheme 与 gtk/icon 主题名）定下来
            case "$mode" in
              dark)
                scheme=prefer-dark
                gtk="${modes.dark.gtk}"
                icons="${modes.dark.icons}"
      ${lib.concatMapStringsSep "\n" (
        t: "          link \"$HOME/${t.live}\" \"$HOME/${t.dark}\""
      ) config.myHome.appearance.switchTargets}
                ;;
              light)
                scheme=prefer-light
                gtk="${modes.light.gtk}"
                icons="${modes.light.icons}"
      ${lib.concatMapStringsSep "\n" (
        t: "          link \"$HOME/${t.live}\" \"$HOME/${t.light}\""
      ) config.myHome.appearance.switchTargets}
                ;;
            esac

            # dconf 侧：GTK4/libadwaita 只认 color-scheme，xdg-desktop-portal 也从这里读，
            # 所以 Electron / 跟随系统的应用看的是这几个键。
            # 注意与 HM 写 dconf 的值同形（org.gnome.desktop.interface）。
            #
            # 两个必须显式给的路径 —— 否则在 systemd 用户服务的环境里会静默地写进
            # 内存后端（实测：clean env 下 gsettings 直接报「No schemas installed」，
            # 加 schema 目录后又因找不到 dconf 模块而回退到内存后端，重启即丢）：
            #   1. schema 搜索路径（GLib 不从 PATH 推）
            #   2. dconf 的 GIO 模块（GSETTINGS_BACKEND=dconf 靠它）
            schema_dir="$(echo ${pkgs.gsettings-desktop-schemas}/share/gsettings-schemas/*/glib-2.0/schemas)"
            if [ -d "$schema_dir" ]; then
              export GSETTINGS_SCHEMA_DIR="$schema_dir''${GSETTINGS_SCHEMA_DIR:+:$GSETTINGS_SCHEMA_DIR}"
            fi
            export GSETTINGS_BACKEND=dconf
            # lib.getLib：dconf 的 GIO 模块在 **-lib 输出**里，写 ${pkgs.dconf}/lib/... 会指向
            # out 输出 —— 那样 gsettings 找不到模块，却仍然退出 0（静默写进内存后端，重启即丢）。
            export GIO_EXTRA_MODULES="${lib.getLib pkgs.dconf}/lib/gio/modules''${GIO_EXTRA_MODULES:+:$GIO_EXTRA_MODULES}"
            gsettings set org.gnome.desktop.interface color-scheme "$scheme"
            gsettings set org.gnome.desktop.interface gtk-theme "$gtk"
            gsettings set org.gnome.desktop.interface icon-theme "$icons"
            # 窗口按钮位置与亮/暗无关，但一并写：HM 只在 activation 时写一次，
            # dconf 被别的东西（GNOME 系工具、临时脚本）改过之后不会自己回去。
            gsettings set org.gnome.desktop.wm.preferences button-layout "${buttonLayout}"

            # 回读校验：dconf 后端不可用时 gsettings 会静默写进内存后端（退出码仍为 0），
            # 那时「跟随系统的应用」永远不跟，而日志里一点异常都没有。
            got="$(gsettings get org.gnome.desktop.interface color-scheme)"
            if [ "$got" != "'$scheme'" ]; then
              echo "theme-apply: dconf 写入未生效（color-scheme 回读为 $got）—— 查 GIO_EXTRA_MODULES 里的 dconf 模块" >&2
              exit 1
            fi
    '';
  };
in
{
  config = lib.mkIf (cfg.enable && desktopCfg.enable) {
    # 本模块自己的 4 个活文件走同一张表（见 modules/home-manager/default.nix 的
    # myHome.appearance.switchTargets）：theme-apply 只做「指软链」，不认具体应用。
    # 第 5 个活文件 gtk.css 不入表：它是模式无关的单一文件（见上面 gtk4UserCss）。
    myHome.appearance.switchTargets = [
      {
        live = ".config/gtk-3.0/settings.ini";
        dark = ".config/${variantDir}/gtk-3.0/dark.ini";
        light = ".config/${variantDir}/gtk-3.0/light.ini";
      }
      {
        live = ".config/gtk-4.0/settings.ini";
        dark = ".config/${variantDir}/gtk-4.0/dark.ini";
        light = ".config/${variantDir}/gtk-4.0/light.ini";
      }
      {
        live = ".config/Kvantum/kvantum.kvconfig";
        dark = ".config/${variantDir}/kvantum/dark.kvconfig";
        light = ".config/${variantDir}/kvantum/light.kvconfig";
      }
      # niri 概览底色，niri 自己会 watch 到 include 的文件并重载。
      # （窗口装饰颜色不在此：Noctalia 模板已停用，用 niri 内置默认。）
      {
        live = ".config/niri-colors/overview.kdl";
        dark = ".config/${variantDir}/niri/overview-dark.kdl";
        light = ".config/${variantDir}/niri/overview-light.kdl";
      }
    ];

    xdg.configFile = variants // {
      # 模式无关：GTK4 的亮/暗在同一份文件里靠 @media 切（不能靠换文件，见 gtk4UserCss）
      # source 必须指到文件：直接把 derivation 交给 HM 会软链整个输出目录。
      "gtk-4.0/gtk.css".source = "${gtk4UserCss}/gtk.css";
    };

    home.packages = [ applyScript ];

    # 窗口按钮位置：dconf 才是真源（settings.ini 那个键对 libadwaita 应用无效，
    # 见上面 buttonLayout 的注释）
    dconf.settings."org/gnome/desktop/wm/preferences".button-layout = buttonLayout;

    # 登录时按当前模式应用一次；此后 Noctalia 的 state 目录一变就再来一次
    systemd.user.services.theme-apply = {
      Unit = {
        Description = "应用 Noctalia 的亮/暗模式到 GTK/Qt/图标/niri";
        # 不要限流：一旦失败，systemd 会让 path 单元后续触发全丢
        # （实测连续 3 次失败后 start-limit-hit，之后 toggle 再也不生效，
        # 而现象只是「部分应用没跟上」，很难联想到限流）。
        # 这个单元每次只翻几个软链，失败就该能重试。
        StartLimitIntervalSec = 0;
        StartLimitBurst = 0;
      };
      Service = {
        Type = "oneshot";
        ExecStart = lib.getExe applyScript;
      };
      Install.WantedBy = [ "default.target" ];
    };

    systemd.user.paths.theme-apply = {
      Unit.Description = "监听 Noctalia theme mode 的变化（temp+rename，故盯目录）";
      Path.PathModified = "${home}/.local/state/noctalia";
      Install.WantedBy = [ "default.target" ];
    };
  };
}
