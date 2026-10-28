# 系统工具 / 实用程序
{
  lib,
  config,
  pkgs,
  myLib,
  ...
}:
let
  cfg = config.myHome.gui.apps.utilities;
  guiCfg = config.myHome.gui;

  eudic-fixed = myLib.wrapQtXWayland {
    inherit pkgs;
    pkg = pkgs.eudic;
    # 窗口 WM_CLASS 为 eudic，而桌面文件 ID 是 eusoft-eudic，需补充
    # StartupWMClass 让 GNOME Shell / Dash to Panel 正确显示应用图标
    startupWMClass = "eudic";
    extraWrapArgs = ''
      --unset QT_STYLE_OVERRIDE \
      --set XKB_CONFIG_ROOT "${pkgs.xkeyboard_config}/share/X11/xkb" \
      --set GST_PLUGIN_SYSTEM_PATH_1_0 ""
    '';
  };
in
{
  options.myHome.gui.apps.utilities.enable = lib.mkOption {
    type = lib.types.bool;
    default = true;
    description = "启用系统工具和实用程序";
  };

  config = lib.mkIf (cfg.enable && guiCfg.enable) {
    home.packages = with pkgs; [
      ddcutil
      file-roller
      papers
      gnome-text-editor
      mission-center # 图形化任务中心
      foliate # eBook阅读器
      gapless # 本地音乐播放器
      xunlei-uos # 迅雷
      qview # 图片查看
      disktree # 磁盘使用情况树状图
      babry # 唯一的截图工具：CV 智能选区 + 标注（快捷键见 binds/system.kdl 的 Mod+P）
      logisim-evolution
      localsend
      eudic-fixed
      magpie # 各 AI agent 的模型选择器（托盘/窗口版；终端版见 hosts/wsl）
    ];

    # babry 的存盘目录。不写这份配置时 babry 按 XDG_PICTURES_DIR 回落，PNG 直接
    # 堆在 ~/Pictures 根下；与 mpv（~/Pictures/mpv）同样单独占一层。目录不存在时
    # 由 babry 在首次存盘/复制/贴图时自建。优先级：--save-dir > BABRY_SAVE_DIR >
    # 本配置 > XDG_PICTURES_DIR，故这条声明就是覆盖回退路径的唯一开关。
    xdg.configFile."babry/config.toml".text = ''
      save_dir = "~/Pictures/screenshots"
    '';

    # `note <文件>`：用 GNOME 文本编辑器打开；无参数时直接开一个空文档。
    # 只在本模块（Linux 桌面工作站）里定义，server / wsl / macbook 不会继承。
    home.shellAliases.note = "${pkgs.gnome-text-editor}/bin/gnome-text-editor";

    # magpie 的桌面文件。上游 internal/gui/scheme_linux.go 的 registerScheme()
    # 首次运行时会往 ~/.local/share/applications/magpie.desktop 写一份，把当时
    # 那个**绝对 store 路径**钉进 Exec=，用来抢占 magpie:// 协议；而它只在
    # 「文件已指向我自己」时跳过后写，于是升级后没人再更新它，启动器与
    # magpie:// 链接就一直拉起上一个版本（CLI 走 PATH，故不受影响）。
    #
    # 这里由 HM 托管同一路径、按当前版本重写 Exec=，每次 rebuild 都指向新版本；
    # 写的是 ${pkgs.magpie} 的绝对路径，正好等于 magpie 自检用的 os.Executable()，
    # 它的自写会命中「已指向我自己」而直接返回，不报错。
    #
    # 不能改用 xdg.desktopEntries：它写进 profile 的 share/applications
    # （XDG_DATA_DIRS），而 GLib 解析桌面文件时 XDG_DATA_HOME(即 ~/.local/share)
    # 优先，会被这份旧文件盖掉、修不好（已用 GLib 实测确认）。HM 首次接管时，
    # 原文件会被备份成 magpie.desktop.hm-bak（后缀非 .desktop，不被当条目解析）。
    xdg.dataFile."applications/magpie.desktop".text = ''
      [Desktop Entry]
      Type=Application
      Name=magpie
      Comment=Every agent's model. One place.
      Exec=${pkgs.magpie}/bin/magpie %u
      Icon=magpie
      Categories=Development;Utility;
      MimeType=x-scheme-handler/magpie;
      Terminal=false
    '';

    # magpie 开机自启（托盘常驻：网关要在登录时就位，各 agent 才连得上）。
    # 不用 magpie 自带的 `magpie autostart on`：它把 os.Executable() 的**绝对
    # store 路径**写进 ~/.config/autostart/magpie.desktop，升级被 GC 后开机就
    # 起不来（与上面桌面文件同一个坑）。照 clash-verge 的既有做法（media.nix）
    # 由 HM 声明一条自制 autostart 条目，Exec 用稳定的命令名走 PATH，恒指向
    # 当前版本；systemd 的 xdg-autostart-generator 会在登录时拉起它。
    # 参数 `tray` 是上游自启的形态（只进托盘、不开窗，见 cli help）。
    xdg.autostart = {
      enable = true;
      entries = [
        (pkgs.writeTextFile {
          name = "magpie.desktop";
          text = ''
            [Desktop Entry]
            Type=Application
            Name=magpie
            Comment=Every agent's model. One place.
            Exec=magpie tray
            Icon=magpie
            Terminal=false
            X-GNOME-Autostart-enabled=true
          '';
        })
      ];
    };

    # === tmp.text 垃圾文件拦截 ===
    # ThunderHelper.node 里残留了一行调试代码 `df -h > tmp.text`，迅雷每次启动都
    # 会把磁盘信息写到进程工作目录（bwrap 沙箱 --chdir $HOME），导致家目录反复
    # 出现 tmp.text。这里把该路径钉成 /dev/null 的符号链接，写入直接进黑洞。
    home.activation.xunleiTmpTextSink = lib.hm.dag.entryAfter [ "writeBoundary" ] (
      lib.optionalString pkgs.stdenv.hostPlatform.isLinux ''
        sink="${config.home.homeDirectory}/tmp.text"
        if [ -L "$sink" ] && [ "$(readlink "$sink")" = "/dev/null" ]; then
          verboseEcho "tmp.text 已指向 /dev/null，无需处理"
        else
          verboseEcho "tmp.text 未锚定到 /dev/null，已重置为符号链接"
          $DRY_RUN_CMD ${pkgs.coreutils}/bin/rm -f "$sink"
          $DRY_RUN_CMD ${pkgs.coreutils}/bin/ln -s /dev/null "$sink"
        fi
      ''
    );
  };
}
