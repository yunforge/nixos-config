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
  # 故此处显式钉 36（KDE 1.5× 会话下与桌面一致；niri 会话的 XCURSOR_SIZE 是 48，
  # laptop 的纯 niri 会话里微信会比桌面略小）。只覆盖微信自身环境。
  # 相关根因/验证见 docs/quirks.md（KDE 光标尺寸条）。
  #
  # 字体：微信主进程（Qt 5.15 静态链接，自绘输入框等控件）对两类字体都渲染偏细，
  # 而内嵌 Chromium（聊天记录）与 fcitx5 候选框正常，于是输入框文字明显细一截：
  #   ① PingFang SC：静态 OTF，但笔画细且无 hinting，Qt5 的 QFontEngineFT 不做
  #      stem darkening，栅格化后比 Chromium 画同一份字更细；
  #   ② nixpkgs 默认的 Noto Sans CJK SC 是 **可变字体** `NotoSansCJK-VF.otf.ttc`，
  #      Qt 5.15 把它的 named-instance 索引传给 FT_New_Face 时丢了低 16 位，FreeType
  #      回落到 VF 默认实例 wght=100（Thin）——实测 QRawFont::styleName() 报 "Thin"，
  #      「测试」着墨量 306，只有 PingFang Regular（710）的 43%，**比 PingFang 更细**。
  # 故只换家族名不够，必须让微信拿到 **静态版** Noto（noto-fonts-cjk-sans-static，
  # 每个字重独立 TTC、index 是纯 face 编号）。这份 fontconfig 做：include 系统
  # fonts.conf（保留无 hinting / 灰度渲染设置）→ 加静态 Noto 目录 → reject VF 版
  # 与 PingFang → 所有 sans 请求自然落到 Noto Sans CJK SC Regular。
  # Qt5 实测：Noto Sans CJK SC / PingFang SC / sans-serif / Noto Sans SC（fcitx5 候选框
  # 请求的家族）全部解析到同一个 Noto Sans CJK SC Regular，ink 689。
  # 根因与验证见 docs/quirks.md（微信输入框文字偏细条）。
  wechat-fonts-conf = pkgs.writeText "wechat-fonts.conf" ''
    <?xml version="1.0"?>
    <!DOCTYPE fontconfig SYSTEM "urn:fontconfig:fonts.dtd">
    <fontconfig>
      <include ignore_missing="yes">/etc/fonts/fonts.conf</include>
      <dir>${pkgs.noto-fonts-cjk-sans-static}/share/fonts/opentype/noto-cjk</dir>
      <selectfont>
        <rejectfont>
          <glob>${pkgs.noto-fonts-cjk-sans}/*</glob>
          <glob>${pkgs.pingfang-sc}/*</glob>
        </rejectfont>
      </selectfont>
    </fontconfig>
  '';
  wechat-scaled = myLib.wrapQtXWayland {
    inherit pkgs;
    pkg = pkgs.wechat;
    extraWrapArgs = ''
      --set XCURSOR_SIZE "36" \
      --set FONTCONFIG_FILE "${wechat-fonts-conf}"
    '';
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
