# 自定义函数库
# 提供跨模块共享的工具函数，避免重复代码
{ lib }:
let
  # 包装 Qt 应用以在 XWayland 下正确运行（带输入法）
  # 许多国产 Qt 应用（微信、欧陆词典等）在 Wayland 原生模式下存在
  # 渲染异常或输入法无法调起的问题，因此统一走 XWayland 回退路径。
  #
  # extraWrapArgs 用于注入应用专属的附加参数（如欧陆词典需要
  # 额外设置 XKB_CONFIG_ROOT 和清理 GST 插件路径）。
  wrapQtXWayland =
    {
      pkgs,
      pkg,
      binary ? null,
      # 可选：若应用运行窗口的 WM_CLASS 与桌面文件 ID 不一致（如欧陆词典窗口类为
      # eudic 而桌面文件是 eusoft-eudic.desktop），GNOME Shell / Dash to Panel 会
      # 无法把窗口与桌面文件关联，导致任务栏显示成通用图标。传入该窗口类名可为
      # 桌面文件补充 StartupWMClass 解决。
      startupWMClass ? null,
      # 需补充 StartupWMClass 的桌面文件名；null 时对包内所有 desktop 文件生效。
      desktopFile ? null,
      extraWrapArgs ? "",
    }:
    let
      # binary 未显式传入时，依次尝试包的 pname 与 meta.mainProgram；
      # 两者皆无则直接报错，避免 baseNameOf 取到 store hash 名（如
      # n8x2...-wechat-4.0.3.3）导致 wrapProgram 找不到可执行文件。
      bin =
        if binary != null then
          binary
        else
          pkg.pname or pkg.meta.mainProgram or (throw "wrapQtXWayland: 无法确定主程序名，请显式传入 binary=...");

      desktopFilePatch = lib.optionalString (startupWMClass != null) ''
        desktopFiles=${
          if desktopFile != null then
            "$out/share/applications/${desktopFile}"
          else
            "$(find $out/share/applications -maxdepth 1 -name '*.desktop' 2>/dev/null || true)"
        }
        for f in $desktopFiles; do
          if [ -L "$f" ]; then
            # 打破符号链接，改为真实文件后再追加内容，避免写入只读的 nix store
            target=$(readlink -f "$f")
            rm -f "$f"
            cp "$target" "$f"
            chmod +w "$f"
          fi
          if ! grep -q '^StartupWMClass=' "$f"; then
            echo "StartupWMClass=${startupWMClass}" >> "$f"
          fi
        done
      '';
    in
    pkgs.symlinkJoin {
      name = "${bin}-wrapped";
      paths = [ pkg ];
      buildInputs = [ pkgs.makeWrapper ];
      postBuild = ''
        wrapProgram $out/bin/${bin} \
          --unset WAYLAND_DISPLAY \
          --set QT_QPA_PLATFORM "wayland;xcb" \
          --set GTK_IM_MODULE "fcitx" \
          --set QT_IM_MODULE "fcitx" \
          --set XMODIFIERS "@im=fcitx" \
          ${extraWrapArgs}
        ${desktopFilePatch}
      '';
    };
in
{
  inherit wrapQtXWayland;

  # 为所有支持的平台生成属性集
  # 用法: forAllSystems (system: pkgs: ...)
  forAllSystems = lib.genAttrs [
    "x86_64-linux"
    "aarch64-darwin"
  ];
}
