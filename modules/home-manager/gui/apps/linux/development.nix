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

  # nixpkgs 以 CVE-2026-111497（上游 2026.2.4.1 内置的 .NET runtime 带漏洞 Brotli）
  # 把 clion 标记为 insecure，纯求值即失败。但 Linux 打包已把 clion-radler 的
  # dotnet 换成 nixpkgs 的 dotnet（runtime 10.0.15），且所有原生库链接 nixpkgs
  # brotli 1.2.1（修复版），本构建实际不受该 CVE 影响，故只从 meta 剔除这一条。
  # 待 nixpkgs 收录 2026.3.0.1+ 并撤销标记后删除（NixOS/nixpkgs#590447）。
  clion = pkgs.jetbrains.clion.overrideAttrs (old: {
    meta = old.meta // {
      knownVulnerabilities = builtins.filter (v: !(lib.hasInfix "CVE-2026-111497" v)) (
        old.meta.knownVulnerabilities or [ ]
      );
    };
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
      (wrapJb "clion" clion)
      github-desktop
      zed-editor
      qtcreator # QT
      heidisql # 数据库
    ];
  };
}
