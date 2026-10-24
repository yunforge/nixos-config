# 终端模拟器（Tern）
#
# Tern（Stencil 出品的多路复用终端，闭源预编译二进制）nixpkgs 未收录，由官方
# 安装包手动装到 ~/Apps/Tern：
#   ~/Apps/Tern/tern       wrapper：补 LD_LIBRARY_PATH 后 exec tern-bin
#   ~/Apps/Tern/tern-bin   官方二进制（wrapper 文件头有重新生成库路径的命令）
#   ~/Apps/Tern/.bin/tern  指向 wrapper 的软链，由本模块加进 sessionPath
#   ~/Apps/Tern/tern.png   从 Tern 自注册的 hicolor 图标里拷出的 512px 图标
# 它启动时 dlopen X11/Wayland/Vulkan 图形栈，nix-ld 默认集没有这些库，裸跑会在
# 出窗前 panic（failed to load libxcb）——由 wrapper 提供库路径。
{
  lib,
  config,
  pkgs,
  ...
}:
let
  cfg = config.myHome.gui.apps.terminal;
  guiCfg = config.myHome.gui;

  ternBin = "${config.home.homeDirectory}/Apps/Tern/.bin";
in
{
  options.myHome.gui.apps.terminal.enable = lib.mkOption {
    type = lib.types.bool;
    default = true;
    description = "启用 Tern 终端（手动安装到 ~/Apps/Tern）";
  };

  config = lib.mkIf (cfg.enable && guiCfg.enable) {
    home.sessionPath = [ ternBin ];

    # 桌面条目由本模块托管，不用 Tern 自带的 `tern register` / 启动时的自动
    # 桌面集成：后者会把 **绝对路径** 写进 ~/.local/share/applications 的
    # so.stencil.tern*.desktop（指向 tern-bin，绕过 wrapper 就丢了库路径），
    # 且每次自更新后可能漂移。settings.json 里关掉 desktop_integration 后
    # Tern 不再写这些文件（实测启动与 self-register 都不再生成），Open With /
    # 默认终端仍可指向这里托管的三份条目。
    # 注意 xdg.dataFile 写的是 ~/.local/share（XDG_DATA_HOME），优先于 profile，
    # 与 utilities.nix 的 magpie.desktop 同一做法。
    xdg.dataFile = {
      "applications/so.stencil.tern.desktop".text = ''
        [Desktop Entry]
        Type=Application
        Name=Tern
        GenericName=Terminal
        Comment=Multiplexing terminal with tabs, splits, file blocks and built-in coding agents
        Exec=${config.home.homeDirectory}/Apps/Tern/tern
        TryExec=${config.home.homeDirectory}/Apps/Tern/tern
        Icon=${config.home.homeDirectory}/Apps/Tern/tern.png
        StartupWMClass=so.stencil.tern
        Terminal=false
        Categories=System;TerminalEmulator;
        X-TerminalArgExec=-e
        Keywords=shell;prompt;command;commandline;
      '';
      "applications/so.stencil.tern.open.desktop".text = ''
        [Desktop Entry]
        Type=Application
        Name=Tern
        Exec=${config.home.homeDirectory}/Apps/Tern/tern --open-file %f
        MimeType=text/plain;text/markdown;text/x-source;image/png;image/jpeg;image/gif;image/webp;image/svg+xml;application/vnd.sqlite3;application/x-sqlite3;application/x-sqbpro;application/x-ipynb+json;
        Icon=${config.home.homeDirectory}/Apps/Tern/tern.png
        StartupWMClass=so.stencil.tern
        NoDisplay=true
        Terminal=false
      '';
      "applications/so.stencil.tern.url.desktop".text = ''
        [Desktop Entry]
        Type=Application
        Name=Tern
        Exec=${config.home.homeDirectory}/Apps/Tern/tern --open-url %u
        MimeType=x-scheme-handler/tern;
        Icon=${config.home.homeDirectory}/Apps/Tern/tern.png
        StartupWMClass=so.stencil.tern
        NoDisplay=true
        Terminal=false
      '';
    };
  };
}
