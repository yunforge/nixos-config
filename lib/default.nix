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
      # 多入口二进制包（如 wpsoffice 的 wps/et/wpp/wpspdf）传 binaries= 逐个
      # wrap；单入口应用维持 binary= 用法不变。
      binaries ? [ ],
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
      bins = if binaries != [ ] then binaries else [ bin ];

      # 每个入口一段相同的 wrapProgram，供 map 拼接
      wrapOne = b: ''
        wrapProgram $out/bin/${b} \
          --unset WAYLAND_DISPLAY \
          --set QT_QPA_PLATFORM "wayland;xcb" \
          --set GTK_IM_MODULE "fcitx" \
          --set QT_IM_MODULE "fcitx" \
          --set XMODIFIERS "@im=fcitx" \
          ${extraWrapArgs}
      '';

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
        ${lib.concatStringsSep "\n" (map wrapOne bins)}
        ${desktopFilePatch}
      '';
    };
in
{
  inherit wrapQtXWayland;

  # 外观主题的家族名常量：同一批字体/光标主题被系统层（fontconfig 回退链、
  # GDM greeter、XWayland 的 XCURSOR_*）与用户层（GTK settings.ini、Qt、
  # niri、Noctalia）按名解析，名字改这里一处即全局同步。
  # 注意：niri 的 cursor.kdl 是 git 内静态文件（mkOutOfStoreSymlink 直连工作树），
  # 无法吃 Nix 插值，改名时它需要手动同步。
  theme = {
    cursor = "Bibata-Modern-Classic";
    fontSans = "HarmonyOS Sans SC";
  };

  # 为所有支持的平台生成属性集
  # 用法: forAllSystems (system: pkgs: ...)
  forAllSystems = lib.genAttrs [
    "x86_64-linux"
    "aarch64-darwin"
  ];
}
