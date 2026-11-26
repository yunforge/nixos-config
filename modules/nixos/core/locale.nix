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
    pingfang-sc # 界面主字体：苹方简体（6 个字重，unfree，自维护包）
    # 全量 CJK 兜底（谚文、罕用汉字；含等宽家族 Noto Sans Mono CJK SC）：
    # 主字体换成 PingFang 后它退居回退链，但 localConf 的兜底家族名仍由它提供，
    # 且 PingFang 不含谚文 / 罕用汉字，必须显式安装、不能靠 enableDefaultPackages 顺带带入
    noto-fonts-cjk-sans
    noto-fonts-cjk-serif # 宋体衬线；拉丁字形即 Source Serif 血统，故不再单装 source-serif-pro
    maple-mono.NormalNL-NF-CN-unhinted # 等宽字体（CN 变体）
    maple-mono.NormalNL-NF-unhinted # 等宽字体（非 CN 变体，补充）
    noto-fonts-color-emoji # Emoji 字体
    lxgw-wenkai # 霞鹜文楷：显式文楷请求；等宽上下文的 CJK 回退见下方 localConf
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

  # 中文回退加固：部分国产 Qt 应用（欧陆词典等）对 fontconfig
  # 的逐字回退依赖不可靠，若命中的字体缺字则直接渲染成方块。无衬线主字体
  # PingFang SC 覆盖常用简体汉字，谚文 / 罕用汉字由下方 localConf 逐名兜底到
  # 全量覆盖的 Noto Sans CJK SC——缺字不会落到楷体风格的文楷。
  fonts.fontconfig.defaultFonts = {
    # 主字体之后的全量兜底：defaultFonts 列表的后续项在主字体缺字时接住，
    # 对不读 localConf 的客户端也有效。
    sansSerif = [
      myLib.theme.fontSans
      "Noto Sans CJK SC"
    ];
    # 宋体对位 macOS 的 Songti SC；Noto Serif CJK 的拉丁字形本就是
    # Source Serif 血统，中英文衬线一支全覆盖
    serif = [ "Noto Serif CJK SC" ];
    monospace = [ "Maple Mono Normal NL NF CN" ];
  };

  # 优先级高于 defaultFonts；给非主字体的中文家族名补一条全量 CJK 兜底
  #
  # 必须用 mode="append"（追加到家族列表**末尾**），不能用 prepend：
  # prepend 是「插到最前」＝把用户请求的家族整个顶掉，兜底字体反而成了主字体
  # （实测见 docs/quirks.md）。append 则保留请求家族，只在缺字时才轮到 Noto。
  #
  # fontconfig 单个 <test> 只允许一个 <string>（多值会告警且丢弃后续值），故逐名拆分。
  fonts.fontconfig.localConf = ''
    <?xml version="1.0"?>
    <!DOCTYPE fontconfig SYSTEM "urn:fontconfig:fonts.dtd">
    <fontconfig>
      <!-- 主字体 PingFang SC 缺字（谚文、罕用汉字）→ 追加 Noto Sans CJK SC 兜底。
           这条在 PingFang 还是「国产 Qt 应用硬编码的家族名」时就有；主字体换成
           PingFang 后它顺带成了主字体的缺字兜底，语义不变。 -->
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
           「这是等宽请求」，只能逐名列举：泛 monospace 与默认等宽家族。必须放在
           下面那条全局 append 之前，让 Mono 变体排在比例版前面。 -->
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
