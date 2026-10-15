# 媒体 / 录屏 / 截图
{
  lib,
  config,
  pkgs,
  ...
}:
let
  cfg = config.mengw.gui.apps.media;
  guiCfg = config.mengw.gui;

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
  options.mengw.gui.apps.media.enable = lib.mkOption {
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
      freetube
      clash-verge-rev # 代理软件（原 flclash 已被 nixpkgs 移除）
      bilibili
    ];

    # 声明式管理 clash-verge 自启：应用自带的 GUI 开关会把 Nix store 路径
    # 写死进 ~/.config/autostart/Clash Verge.desktop，升级被 GC 后开机不自启。
    # 改用 xdg.autostart.entries 链接自制 desktop 文件，Exec 用稳定的
    # clash-verge 命令名（meta.mainProgram），恒指向当前版本。
    xdg.autostart = {
      enable = true;
      entries = [
        (pkgs.writeTextFile {
          name = "clash-verge.desktop";
          text = ''
            [Desktop Entry]
            Type=Application
            Name=Clash Verge
            Comment=Clash Verge 开机自启
            Exec=clash-verge
            Icon=clash-verge
            StartupWMClass=clash-verge
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
