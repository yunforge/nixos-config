# 生产力 / 笔记 / 文献管理
{
  lib,
  config,
  pkgs,
  myLib,
  ...
}:
let
  cfg = config.myHome.gui.apps.productivity;
  guiCfg = config.myHome.gui;

  # Obsidian 关闭内置更新器：它会把新版 asar 下到 ~/.config/obsidian/ 并优先
  # 加载，绕过 nixpkgs 的打包改动（上游 asar 没有 nixpkgs 修 PDF 阅读器的
  # corsEnabled 补丁）；2026-10-24 该外来 bundle 与用户目录里累积的 V8 code
  # cache 混用，渲染进程 `webFrame is not a function` 直接黑屏（删 Code Cache
  # 即恢复，已 A/B 复现）。三处改动：`disable` 初值与赋值都给真值（设置项
  # 也翻不回来），再关掉启动时「优先加载已下载 asar」的分支。升级改走 nixpkgs。
  # 根因与移除条件见 docs/quirks.md。
  obsidianNoUpdater = pkgs.obsidian.overrideAttrs (
    finalAttrs: previousAttrs: {
      postInstall = (previousAttrs.postInstall or "") + ''
        rm -rf obsidian-app
        asar extract $out/share/obsidian/app.asar obsidian-app
        substituteInPlace obsidian-app/main.js \
          --replace-fail "let disable = false;" "let disable = true;" \
          --replace-fail "disable = arg;" "disable = true;" \
          --replace-fail "if (version && (isV2MoreRecent(appVersion, version) || appVersion === version)) {" "if (false) {"
        rm -f $out/share/obsidian/app.asar
        asar pack obsidian-app $out/share/obsidian/app.asar
      '';
    }
  );

  # WPS：自带 Qt5（libQt5CoreKso 等）与自带的 fcitx 输入法插件
  # （office6/qt/plugins/platforminputcontexts/），该插件仅在
  # QT_IM_MODULE=fcitx 时被 Qt 加载，而 Qt5 无 XIM（全局 XMODIFIERS 兜不住）；
  # 全局 QT_IM_MODULE 删除后（见 docs/input.md 路线变更）照微信/欧陆词典
  # 按应用注入。desktop 文件 Exec 是裸命令名走 PATH，四个入口都要 wrap。
  wpsoffice-wrapped = myLib.wrapQtXWayland {
    inherit pkgs;
    pkg = pkgs.wpsoffice-cn;
    binaries = [
      "wps"
      "et"
      "wpp"
      "wpspdf"
    ];
  };
in
{
  options.myHome.gui.apps.productivity.enable = lib.mkOption {
    type = lib.types.bool;
    default = true;
    description = "启用生产力应用（笔记、文献管理等）";
  };

  config = lib.mkIf (cfg.enable && guiCfg.enable) {
    home.packages = with pkgs; [
      zotero
      anki
      xmind
      siyuan # 笔记软件
      obsidianNoUpdater # 笔记软件（pkgs.obsidian 关掉内置更新器，见上方 let 块）
      typora # markdown 编辑器
      wpsoffice-wrapped # WPS 办公套件（中文；wrap 注入 IM 变量，见上方 let 块）
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
  };
}
