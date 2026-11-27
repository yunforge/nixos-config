# MacTahoe Kvantum 主题（vinceliuice，macOS Tahoe 风格的 Qt 主题）
# nixpkgs 未收录，此处仿照 MacTahoe GTK / 图标主题打包。
#
# 上游仓库是整套 KDE 主题包，这里只取其中的 Kvantum 部分：plasma /
# aurorae / look-and-feel 面向 Plasma 桌面，与本机（niri + Noctalia）无关，
# 装进来只会增大闭包。
{
  lib,
  stdenv,
  fetchFromGitHub,
}:

stdenv.mkDerivation {
  pname = "mactahoe-kvantum";
  version = "unstable-2026-08-16";

  src = fetchFromGitHub {
    owner = "vinceliuice";
    repo = "MacTahoe-kde";
    rev = "cbf6a1f71b591d143184855d62f6272ce533e7c3";
    hash = "sha256-atdHgr9pCfg/VE8GGWF+4MZu6nRmVCz9TiylVATAwzs=";
  };

  dontBuild = true;

  installPhase = ''
    runHook preInstall

    mkdir -p $out/share/Kvantum

    # 上游目录里浅深两态并存（MacTahoe.kvconfig/.svg 与 MacTahoeDark.kvconfig/.svg），
    # 原样保留，便于以后在 kvantummanager 里切换。
    cp -r Kvantum/MacTahoe $out/share/Kvantum/MacTahoe

    # 另建一个只含深色那一对的独立主题名。
    # 原因：Kvantum 选浅色还是深色取决于应用的 QPalette 明暗，而在非 Plasma
    # 会话下这个值来自平台主题（本机是 qadwaitadecorations），并不可靠。
    # Kvantum 的查找规则是"主题 T → T.kvconfig；若应用偏暗且存在 TDark.kvconfig
    # 则改用它"。所以把深色那对命名为主题 MacTahoeDark 后，选中它必然命中
    # MacTahoeDark.kvconfig（它要去找的 MacTahoeDarkDark.kvconfig 并不存在），
    # 与本仓库其余部分"只用深色"的做法一致。
    mkdir -p $out/share/Kvantum/MacTahoeDark
    cp Kvantum/MacTahoe/MacTahoeDark.kvconfig Kvantum/MacTahoe/MacTahoeDark.svg \
      $out/share/Kvantum/MacTahoeDark/

    chmod -R u+w $out/share/Kvantum

    # 强调色对齐壳层。
    # 上游的 kvconfig 用 #a0b4f8（浅紫蓝）作 highlight，而同一个作者的 GTK 主题
    # 用的是 #0088FF —— 两套主题同源却不同色。这里统一到壳层值，与 niri 焦点环、
    # GTK、Noctalia 调色板的 mPrimary 一致。
    # 注意替换顺序：'inactive.highlight.color=...' 必须先于 'highlight.color=...'，
    # 因为后者是前者的子串（substituteInPlace 替换的是字面量，不是单词边界）。
    substituteInPlace \
      $out/share/Kvantum/MacTahoe/MacTahoeDark.kvconfig \
      $out/share/Kvantum/MacTahoeDark/MacTahoeDark.kvconfig \
      --replace-fail 'inactive.highlight.color=#a0b4f8' 'inactive.highlight.color=#0088FF' \
      --replace-fail 'highlight.color=#a0b4f8' 'highlight.color=#0088FF' \
      --replace-fail 'link.color=#3484e2' 'link.color=#0088FF'

    runHook postInstall
  '';

  meta = {
    description = "MacOS Tahoe like Kvantum (Qt) theme";
    homepage = "https://github.com/vinceliuice/MacTahoe-kde";
    license = lib.licenses.mit;
    platforms = lib.platforms.unix;
  };
}
