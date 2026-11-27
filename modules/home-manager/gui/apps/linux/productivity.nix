# 生产力 / 笔记 / 文献管理
{
  lib,
  config,
  pkgs,
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
      dalibre # calibre 书库管理器（自维护包，见 pkgs/dalibre）
      xmind
      siyuan # 笔记软件
      obsidianNoUpdater # 笔记软件（pkgs.obsidian 关掉内置更新器，见上方 let 块）
      typora # markdown 编辑器
    ];

    # 思源笔记是 Electron 应用，其 package.json 的 desktopName 为 "org.b3log.siyuan"，
    # Electron 启动时会自动调用 app.setDesktopName()，该值经 Wayland xdg_toplevel.set_app_id
    # 成为窗口 app_id。而 nixpkgs 包提供的 siyuan.desktop 未设置 StartupWMClass，
    # 导致 KDE / niri 的任务栏匹配不到应用，图标回退为 application-x-executable（齿轮图标）。
    # 通过 StartupWMClass 把窗口 app_id 关联回 siyuan.desktop，即可命中 Icon=siyuan。
    # 注意：生效需重新登录（KWin / niri 在会话启动时读取桌面条目）。
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
