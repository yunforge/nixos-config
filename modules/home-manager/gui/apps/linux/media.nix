# 媒体 / 录屏 / 截图
{
  lib,
  config,
  pkgs,
  ...
}:
let
  cfg = config.myHome.gui.apps.media;
  guiCfg = config.myHome.gui;

  picgo-clipboard-upload = pkgs.writeShellScriptBin "picgo-clipboard-upload" ''
    set -euo pipefail
    TMPFILE=$(mktemp -t picgo-upload.XXXXXX.png)
    trap 'rm -f "$TMPFILE"' EXIT
    if ! ${pkgs.wl-clipboard}/bin/wl-paste --type image/png > "$TMPFILE" 2>/dev/null; then
      ${pkgs.libnotify}/bin/notify-send -u critical \
        -i dialog-error \
        "PicGo 上传失败" "剪贴板中没有图片"
      exit 1
    fi
    if [ ! -s "$TMPFILE" ]; then
      ${pkgs.libnotify}/bin/notify-send -u critical \
        -i dialog-error \
        "PicGo 上传失败" "剪贴板图片为空"
      exit 1
    fi
    RESPONSE=$(${pkgs.curl}/bin/curl -s -X POST http://127.0.0.1:36677/upload \
      -H "Content-Type: application/json" \
      -d "{\"list\":[\"$TMPFILE\"]}" 2>/dev/null || echo "")
    URL=$(echo "$RESPONSE" | ${pkgs.jq}/bin/jq -r \
      '.result[0] // .data[0] // .result // .data // empty' 2>/dev/null || echo "")
    if [ -n "$URL" ] && [ "$URL" != "null" ]; then
      echo -n "$URL" | ${pkgs.wl-clipboard}/bin/wl-copy
      ${pkgs.libnotify}/bin/notify-send \
        -i picgo \
        "PicGo 上传成功" "URL 已复制到剪贴板"
    else
      ERR_MSG=$(echo "$RESPONSE" | ${pkgs.jq}/bin/jq -r \
        '.message // .error // "Server 未响应"' 2>/dev/null || echo "$RESPONSE")
      ${pkgs.libnotify}/bin/notify-send -u critical \
        -i dialog-error \
        "PicGo 上传失败" "请确认 PicGo 已启动且 Server 已开启（端口 36677）"
      exit 1
    fi
  '';

  picgo-wrapped = pkgs.symlinkJoin {
    name = "picgo-wrapped";
    paths = [ pkgs.picgo ];
    buildInputs = [ pkgs.makeWrapper ];
    postBuild = ''
      wrapProgram $out/bin/picgo \
        --set ELECTRON_OZONE_PLATFORM_HINT wayland \
        --set NIXOS_OZONE_WL 1 \
        --prefix PATH : ${pkgs.wl-clipboard}/bin
    '';
  };
in
{
  options.myHome.gui.apps.media.enable = lib.mkOption {
    type = lib.types.bool;
    default = true;
    description = "启用媒体和录屏应用";
  };

  config = lib.mkIf (cfg.enable && guiCfg.enable) {
    home.packages = with pkgs; [
      obs-studio
      picgo-wrapped
      picgo-clipboard-upload
      wl-clipboard
      flclash # 代理客户端（nixpkgs 已移除 flclash，本仓库自维护，见 pkgs/flclash/）
      bilibili
    ];

    # 声明式管理 FlClash 自启：应用自带的「开机自启」开关（设置里的
    # autoLaunch）会把当时的**绝对 store 路径**写进 ~/.config/autostart/
    # FlClash.desktop，升级被 GC 后开机不自启（与 magpie / clash-verge 同一个坑，
    # 见 docs/quirks.md）。故用 xdg.autostart.entries 自制 desktop 文件，Exec 用
    # 稳定的 FlClash 命令名（meta.mainProgram），恒指向当前版本；应用内那个
    # 开关要保持关闭，否则两个自启条目会各拉起一个实例。
    xdg.autostart = {
      enable = true;
      entries = [
        (pkgs.writeTextFile {
          name = "flclash.desktop";
          text = ''
            [Desktop Entry]
            Type=Application
            Name=FlClash
            Comment=FlClash 开机自启
            Exec=FlClash
            Icon=flclash
            StartupWMClass=com.follow.clash
            Terminal=false
            X-GNOME-Autostart-enabled=true
          '';
        })
      ];
    };

    # bilibili 上游 bug: ~/.config/bilibili/bilibili-flags.conf 中
    # host-resolver-rules 使用了 "http://localhost:3031" 格式，
    # Chromium 不支持带 scheme 前缀的 replacement，导致 DNS 解析失败。
    # 修复: 使用正确格式 "127.0.0.1:3031"
    xdg.configFile."bilibili/bilibili-flags.conf".text = ''
      --host-resolver-rules=MAP bilipc.bilibili.com 127.0.0.1:3031
    '';
  };
}
