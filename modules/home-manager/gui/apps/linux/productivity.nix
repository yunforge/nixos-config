# 生产力 / 笔记 / 文献管理
{
  lib,
  config,
  pkgs,
  ...
}:
let
  cfg = config.mengw.gui.apps.productivity;
  guiCfg = config.mengw.gui;

  # Thunderbird 的 profile 目录：前缀是 TB 首次启动时自己生成的随机串，除了
  # ~/.thunderbird/profiles.ini 的 Path= 之外没有稳定来源（HM 读不到那个文件，
  # 也不该替它建 profile —— 那是 TB 的运行时状态）。故做成可选值，每台主机
  # 自己对上（`grep '^Path=' ~/.thunderbird/profiles.ini`）。
  tbProfile = ".thunderbird/${cfg.thunderbirdProfileDir}";
  lbChrome = "${pkgs.liquidbird}/share/liquidbird/chrome";
in
{
  options.mengw.gui.apps.productivity.enable = lib.mkOption {
    type = lib.types.bool;
    default = true;
    description = "启用生产力应用（笔记、文献管理等）";
  };

  options.mengw.gui.apps.productivity.thunderbirdProfileDir = lib.mkOption {
    type = lib.types.str;
    default = "g0uk404f.default";
    description = ''
      ~/.thunderbird 下 Thunderbird 自己那个 profile 目录名，用于摆 LiquidBird
      主题（只是目录名，不是路径）。前缀由 TB 生成、每台主机不同；对不上的主机
      会在 ~/.thunderbird 下生成一个 TB 不读的目录，主题不生效。
    '';
  };

  config = lib.mkIf (cfg.enable && guiCfg.enable) {
    home.packages = with pkgs; [
      # zotero
      # ⚠️ 暂注释：nixpkgs 升到 zotero 10.0.4 后构建失败（firefox 版本错配），
      # 上游 nixpkgs#568692 修复后取消注释。根因与移除条件见 docs/quirks.md。
      anki
      xmind
      siyuan # 笔记软件
      obsidian # 笔记软件
      typora # markdown 编辑器
      thunderbird # 邮件管理
      wpsoffice-cn # 微软办公套件（中文）
    ];

    # 思源笔记是 Electron 应用，其 package.json 的 desktopName 为 "org.b3log.siyuan"，
    # Electron 启动时会自动调用 app.setDesktopName()，该值经 Wayland xdg_toplevel.set_app_id
    # 由 mutter 写入窗口的 wm_class。而 nixpkgs 包提供的 siyuan.desktop 未设置 StartupWMClass，
    # 导致 GNOME Shell 匹配不到应用，Dash to Panel 图标回退为 application-x-executable（齿轮图标）。
    # 通过 StartupWMClass 把窗口 app_id 关联回 siyuan.desktop，即可命中 Icon=siyuan。
    # 注意：生效需重启 GNOME Shell（Alt+F2 → r）或重新登录。
    xdg.desktopEntries.siyuan = {
      name = "SiYuan";
      comment = "Refactor your thinking";
      exec = "siyuan %U";
      icon = "siyuan";
      categories = [ "Utility" ];
      type = "Application";
      settings.StartupWMClass = "org.b3log.siyuan";
    };

    # ── LiquidBird：Thunderbird 的 Liquid Glass 主题 ──────────────────────
    # 由 pkgs/liquidbird 提供文件（钉在上游 main 的 commit，见该包顶部），这里
    # 按上游要求的 chrome/ 布局摆进 profile。store 软链即可：chrome 下全是只读
    # 素材，TB 只读不写。
    home.file = {
      "${tbProfile}/chrome/liquidbird.css".source = "${lbChrome}/liquidbird.css";
      "${tbProfile}/chrome/liquidbird-content.css".source = "${lbChrome}/liquidbird-content.css";
      # 两个 loader 用上游原件：升级包时 import 列表跟着走，不用手工合并
      "${tbProfile}/chrome/userChrome.css".source = "${lbChrome}/userChrome.css";
      "${tbProfile}/chrome/userContent.css".source = "${lbChrome}/userContent.css";
      # 图标集 + Linux 层（模糊/布局/标题按钮图）；相对路径必须原样保留
      "${tbProfile}/chrome/Icons".source = "${lbChrome}/Icons";
      "${tbProfile}/chrome/linux".source = "${lbChrome}/linux";
      "${tbProfile}/chrome/custom.css.example".source = "${lbChrome}/custom.css.example";

      # 覆盖层：上游 loader 最后 import 的 custom.css，原为个人手改留的槽位，
      # 现由 HM 持有（唯一用途见下）。想加个人 tweaks 请改本模块，别直接编辑该文件
      # （store 软链，手改会在下次 rebuild 被覆盖）。
      "${tbProfile}/chrome/custom.css".text = ''
        /* 由 Home Manager 生成（modules/home-manager/gui/apps/productivity.nix） */
        /* LiquidBird 的 linux/titlebuttons.css 用 row-reverse 把红黄绿灯钉在物理左缘
           （见其注释），与桌面其余部分（dconf button-layout 放右侧）不一致。
           TB 模板本就把按钮盒放在 #unifiedToolbar 之后，改回 row 即回到右侧。 */
        :root[customtitlebar] #unifiedToolbarContainer {
          flex-direction: row !important;
        }
      '';

      # 主题开关。写 user.js 而不是 prefs.js：后者是 TB 自己维护的文件（它随时
      # 重写），HM 插手会与 TB 相互覆盖；user.js 由 Gecko 在每次启动时应用。
      # 代价是这一项被钉住 —— 在 TB 的 Config Editor 里关它下次启动会回来，
      # 要关主题就从这个模块里去掉下面几行。
      "${tbProfile}/user.js".text = ''
        // 由 Home Manager 生成（modules/home-manager/gui/apps/productivity.nix），
        // 不要手改：TB 每次启动都会按这里的内容覆盖同名 prefs。
        user_pref("toolkit.legacyUserProfileCustomizations.stylesheets", true);

        // 阻止 TB 每次启动重抢邮件默认程序。打包默认是 true，一旦它认为默认程序
        // 不是自己，就调 libgio 在 ~/.local/share/applications/ 里 mkstemp 出新的
        // userapp-Thunderbird-XXXXXX.desktop（不复用），于是不断堆积。邮件默认程序
        // 已由 mimeapps.nix 声明式指定，无需 TB 再插手。
        user_pref("mail.shell.checkDefaultClient", false);
      '';
    };
  };
}
