# 通讯工具
{
  lib,
  config,
  pkgs,
  myLib,
  ...
}:
let
  cfg = config.myHome.gui.apps.communication;
  guiCfg = config.myHome.gui;

  # 微信内嵌的 Chromium(WeChatAppEx) 在 Ozone/X11 下按 `XCURSOR_SIZE`（物理像素）
  # 在其光标主题里挑“最接近的位图”，**不会**再乘设备缩放比。桌面（KWin 逻辑 24 ×1.5）
  # 与欧陆(Qt/QtWebEngine)都是 36px。此前 Bibata 主题没有 36 档，微信请求 36 只能拿到
  # 最接近的 32px → 比桌面小一截，故“样式对不齐”。我们在 overlays 里给 Bibata 补了 36px
  # 档位后，只要让微信拿到 `XCURSOR_SIZE=36` 就会选到真正的 36px 位图，与桌面/欧陆一致。
  # 故此处显式钉 36（与会话默认一致，防未来会话默认变动）。只覆盖微信自身环境。
  # 相关根因/验证见 docs/quirks.md（KDE 光标尺寸条）。
  wechat-scaled = myLib.wrapQtXWayland {
    inherit pkgs;
    pkg = pkgs.wechat;
    extraWrapArgs = "--set XCURSOR_SIZE \"36\"";
  };
in
{
  options.myHome.gui.apps.communication.enable = lib.mkOption {
    type = lib.types.bool;
    default = true;
    description = "启用通讯工具";
  };

  config = lib.mkIf (cfg.enable && guiCfg.enable) {
    home.packages = with pkgs; [
      discord
      telegram-desktop
      wechat-scaled # 微信
      wemeet # 腾讯会议
      qq
    ];
  };
}
