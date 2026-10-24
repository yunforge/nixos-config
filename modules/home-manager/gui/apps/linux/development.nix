# 开发工具
{
  lib,
  config,
  pkgs,
  ...
}:
let
  cfg = config.myHome.gui.apps.development;
  guiCfg = config.myHome.gui;

  # skiko 渲染层依赖的运行时库。nixpkgs master 的 jetbrains 包装器把
  # LD_LIBRARY_PATH 清空，导致 libskiko-linux-x64.so 加载不到 libGL.so.1，
  # 所有 JB 产品 UI 渲染崩溃（UnsatisfiedLinkError: BitmapKt._nMake）。
  skikoLibs = lib.makeLibraryPath [
    pkgs.libglvnd
    pkgs.libx11
    pkgs.fontconfig
    pkgs.stdenv.cc.cc.lib
  ];

  # 在 JetBrains 启动脚本 exec 前注入 LD_LIBRARY_PATH
  wrapJb =
    binName: pkg:
    pkg.overrideAttrs (old: {
      postInstall = (old.postInstall or "") + ''
        sed -i '/^exec -a/i export LD_LIBRARY_PATH="${skikoLibs}"''${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}' "$out/bin/${binName}"
      '';
    });
in
{
  options.myHome.gui.apps.development.enable = lib.mkOption {
    type = lib.types.bool;
    default = true;
    description = "启用开发工具应用";
  };

  config = lib.mkIf (cfg.enable && guiCfg.enable) {
    home.packages = with pkgs; [
      (wrapJb "clion" jetbrains.clion)
      github-desktop
      zed-editor
      qtcreator # QT
      heidisql # 数据库
      cutecom # 简单的图形化串口终端模拟器
    ];
  };
}
