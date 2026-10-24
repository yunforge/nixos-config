# NixOS 本地化配置
{
  config,
  pkgs,
  myLib,
  ...
}:
{
  # 时区
  time.timeZone = "Asia/Shanghai";

  i18n.defaultLocale = "zh_CN.UTF-8";
  i18n.supportedLocales = [
    "zh_CN.UTF-8/UTF-8"
    "en_US.UTF-8/UTF-8"
  ];
  i18n.extraLocaleSettings = {
    LC_ADDRESS = "zh_CN.UTF-8";
    LC_IDENTIFICATION = "zh_CN.UTF-8";
    LC_MEASUREMENT = "zh_CN.UTF-8";
    LC_MONETARY = "zh_CN.UTF-8";
    LC_NAME = "zh_CN.UTF-8";
    LC_NUMERIC = "zh_CN.UTF-8";
    LC_PAPER = "zh_CN.UTF-8";
    LC_TELEPHONE = "zh_CN.UTF-8";
    LC_TIME = "zh_CN.UTF-8";
    LC_CTYPE = "en_US.UTF-8";
  };

  # 启用默认字体包
  fonts.enableDefaultPackages = true;
  fonts.fontDir.enable = true;

  fonts.packages = with pkgs; [
    pkgs.nur.repos.guanran928.harmonyos-sans # 无衬线字体（界面主字体）
    # 全量 CJK 兜底（谚文、罕用汉字；含等宽家族 Noto Sans Mono CJK SC）。
    # 显式安装——localConf 的兜底家族名由它提供，不再依赖 enableDefaultPackages 顺带带入
    noto-fonts-cjk-sans
    noto-fonts-cjk-serif # 宋体衬线；拉丁字形即 Source Serif 血统，故不再单装 source-serif-pro
    maple-mono.NormalNL-NF-CN-unhinted # 等宽字体（CN 变体）
    maple-mono.NormalNL-NF-unhinted # 等宽字体（非 CN 变体，补充）
    noto-fonts-color-emoji # Emoji 字体
    lxgw-wenkai # 霞鹜文楷：ghostty 的 CJK 回退（含 Mono 变体）与显式文楷请求
  ];

  # ── 字形渲染：灰度 + 不 hinting（macOS 自 Mojave 起就是这套）────────────
  # 这两件事是一对：hinting 把笔画对齐到像素网格，次像素渲染再借 R/G/B 子像素
  # 骗出更高的横向分辨率 —— 两者都是为了在小字号下抢清晰度，代价是字形失去字体
  # 原本的比例、字边出现彩边。这里两个都不要。
  #
  # autohint 尤其与字体选型矛盾：fonts.packages 里的等宽字体特意选了 **-unhinted**
  # 构建（同一包也有 NormalNL-NF / NormalNL-NF-CN 两个 hinted 变体而没选），
  # 而 autohint 正是对“没有自带 hinting”的字体生效的开关 —— 等于把那份刻意
  # 不 hinting 的轮廓重新对齐一遍。
  #
  # 说明：hinting.style 与 subpixel.* 不是写进生成的那个 conf 文件，而是替换
  # conf.d 里指向 fontconfig 自带预设的软链（10-hinting-none.conf /
  # 10-sub-pixel-none.conf），所以核实时要看软链目标。
  fonts.fontconfig.hinting.style = "none";
  fonts.fontconfig.hinting.autohint = false;
  fonts.fontconfig.subpixel.rgba = "none";
  # 不写 subpixel.lcdfilter：LCD 滤镜只对次像素渲染有意义，rgba = none 时它是空转，
  # 而它的默认值本来就是 "default"（即上游默认，不替换任何 conf.d 软链）。

  # 中文回退加固：部分国产 Qt 应用（迅雷、欧陆词典等）对 fontconfig
  # 的逐字回退依赖不可靠，若命中的字体缺字则直接渲染成方块。defaultFonts
  # 把全量覆盖的 Noto CJK 排进无衬线链第二位——缺字先落**中性无衬线**的
  # Noto，而不是楷体风格的文楷；常见中文家族名的逐名兜底见下方 localConf。
  fonts.fontconfig.defaultFonts = {
    sansSerif = [
      myLib.theme.fontSans
      "Noto Sans CJK SC"
    ];
    # 宋体对位 macOS 的 Songti SC；Noto Serif CJK 的拉丁字形本就是
    # Source Serif 血统，中英文衬线一支全覆盖
    serif = [ "Noto Serif CJK SC" ];
    monospace = [ "Maple Mono Normal NL NF CN" ];
  };

  # 优先级高于 defaultFonts；给中文家族名补一条全量 CJK 兜底
  #
  # 必须用 mode="append"（追加到家族列表**末尾**），不能用 prepend：
  # prepend 是「插到最前」＝把用户请求的家族整个顶掉。实测 prepend + binding="strong"
  # 会让 `fc-match "HarmonyOS Sans SC"` 返回 Noto Sans CJK SC —— GTK 的 gtk-font-name
  # 与 Noctalia 的 font_family 都写的是 HarmonyOS，于是界面实际全程在渲染 Noto 的
  # 拉丁字形，HarmonyOS 从未被用上。append 则保留请求家族，只在缺字时才轮到 Noto。
  #
  # fontconfig 单个 <test> 只允许一个 <string>（多值会告警且丢弃后续值），故逐名拆分。
  fonts.fontconfig.localConf = ''
    <?xml version="1.0"?>
    <!DOCTYPE fontconfig SYSTEM "urn:fontconfig:fonts.dtd">
    <fontconfig>
      <!-- 无衬线中文家族 → 追加 Noto Sans CJK SC 兜底（HarmonyOS Sans SC 自带假名，
           但无谚文，缺字时由 Noto 接住） -->
      <match target="pattern">
        <test qual="any" name="family">
          <string>${myLib.theme.fontSans}</string>
        </test>
        <edit name="family" mode="append" binding="weak">
          <string>Noto Sans CJK SC</string>
        </edit>
      </match>
      <match target="pattern">
        <test qual="any" name="family">
          <string>PingFang SC</string>
        </test>
        <edit name="family" mode="append" binding="weak">
          <string>Noto Sans CJK SC</string>
        </edit>
      </match>

      <!-- 衬线/宋体中文家族 → 追加 Noto Serif CJK SC 兜底 -->
      <match target="pattern">
        <test qual="any" name="family">
          <string>LXGW WenKai</string>
        </test>
        <edit name="family" mode="append" binding="weak">
          <string>Noto Serif CJK SC</string>
        </edit>
      </match>

      <!-- 等宽上下文的中文回退要用 LXGW WenKai **Mono**（比例版会破中文对齐），
           再兜 Noto Sans Mono CJK SC 补全量覆盖。fontconfig 无法从任意家族名判断
           「这是等宽请求」，只能逐名列举：泛 monospace 与默认等宽家族（ghostty
           自己显式配了 WenKai Mono，不依赖这条）。必须放在下面那条全局 append
           之前，让 Mono 变体排在比例版前面。 -->
      <match target="pattern">
        <test qual="any" name="family">
          <string>monospace</string>
        </test>
        <edit name="family" mode="append" binding="weak">
          <string>LXGW WenKai Mono</string>
        </edit>
        <edit name="family" mode="append" binding="weak">
          <string>Noto Sans Mono CJK SC</string>
        </edit>
      </match>
      <match target="pattern">
        <test qual="any" name="family">
          <string>Maple Mono Normal NL NF CN</string>
        </test>
        <edit name="family" mode="append" binding="weak">
          <string>LXGW WenKai Mono</string>
        </edit>
        <edit name="family" mode="append" binding="weak">
          <string>Noto Sans Mono CJK SC</string>
        </edit>
      </match>

      <!-- 兜底：任何请求的家族都追加全量中文字体，避免 Qt 短回退链够不到 -->
      <match target="pattern">
        <edit name="family" mode="append">
          <string>LXGW WenKai</string>
        </edit>
      </match>
    </fontconfig>
  '';
}
