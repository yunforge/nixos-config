# mpv 播放器 —— uosc 定制「Cupertino」界面
#
# 配置树 mpv/ 整棵 vendored 自 https://github.com/StatIndet/mpv
# （commit f6c617b，2026-09-29；上游 README.md / CUSTOMIZATION.md 一并保留，
# 里面有全部界面的取值理由）。原创部分 MIT，uosc / thumbfast / stats / mpv
# 等第三方各自保留原许可证，见 mpv/LICENSE、mpv/LICENSES/ 与 mpv/THIRD_PARTY.md
# —— 整目录并非统一 MIT。
#
# ~/.config/mpv 是指向 store 的**只读**目录软链（同 nvim 的做法）。敢整目录软链
# 是因为该目录里没有任何运行时写入，逐项核过：
#   - 播放位置 watch_later → mpv 0.41 落在 $XDG_STATE_HOME/mpv/watch_later
#   - thumbfast 的 socket → /tmp/thumbfast<唯一后缀>（thumbfast.conf 留空 = auto）
#   - screenshot-directory → ~/Pictures/mpv，mpv 首次截图时自建（manpage 明说）
#   - uosc / stats / seek_feedback 都不写文件
# 升级：把上游内容覆盖回 mpv/ 即可。**不要**用 uosc 官方安装器，它会覆盖定制 Lua。
#
# ── 对上游源码的本地改动（升级后需要重新打上）──────────────────────────────
# 上游把界面文字的字体**写死在 Lua 里**（`font = 'Noto Sans'`），共 4 处：
#   scripts/uosc/elements/{Timeline,TopBar,Volume}.lua、scripts/seek_feedback.lua
# 而本机没装 Noto Sans（只有 Noto Sans **CJK**），故全部改成 `'sans-serif'`：
# 确定性命中 fonts.fontconfig.defaultFonts.sansSerif 首项 = HarmonyOS Sans SC
# （与菜单/OSD 文字一致，它们本来就走 mpv 的 --osd-font 默认值 sans-serif）。
# 实测 fc-match：`sans-serif` 与 `Noto Sans` 在本机落到**同一个文件**
# HarmonyOS_Sans_SC_Regular.ttf，故这是「把运气改成显式」，视觉不变。
# ⚠️ 别写成 `'HarmonyOS Sans SC'`：modules/nixos/core/locale.nix 的 localConf 对该
# 家族名做了 `prepend binding="strong"` → 实际拿到 Noto Sans CJK SC，与本意相反。
#
# 字体：uosc 被改造成用 ASS 字体 CupertinoIcons（名字写死在 scripts/uosc/lib/ass.lua，
# 不是 mpv.conf 选项）—— 全部图标（播放/暂停、音量、菜单、buffering spinner、顶栏
# 按钮、seek 标记）都走它，13 处 `ass:icon(...)` 调用；字形是 lib/cupertino.lua 里
# Flutter Cupertino Icons 的私有区码位，所以**必须**自带（系统与 nixpkgs 都没有这支），
# 装进 ~/.local/share/fonts（/etc/fonts/fonts.conf 有 <dir prefix="xdg">fonts</dir>，
# 不需要额外声明 fontconfig）。
#
# 上游树里另有一支 `fonts/uosc_textures.ttf`，**不安装**：唯一引用它的 `ass:texture()`
# 在本 fork 里没有任何调用点（全树 grep 过，暗化遮罩 Curtain 已改成纯矩形绘制）。
# 文件留在 vendored 树里保持与上游一致；若将来重新 vendored 后出现了 `ass:texture(`
# 的调用（历史上用它画菜单暗化的斜纹底），把下面这行再补回去即可。
#
# mpv.conf 里 vo=gpu-next / gpu-api=vulkan / hwdec=nvdec 是上游按 NVIDIA 给的。本仓库
# 只有 desktop / laptop 导入 gui/，两台都是 NVIDIA（hosts/*/nvidia.nix），故可直接用；
# 换 AMD/Intel 主机时改成 hwdec=auto-safe 并按显卡调 gpu-api。
{
  lib,
  config,
  pkgs,
  ...
}:
let
  cfg = config.mengw.gui.apps.mpv;
  guiCfg = config.mengw.gui;
in
{
  options.mengw.gui.apps.mpv.enable = lib.mkOption {
    type = lib.types.bool;
    default = true;
    description = "启用 mpv（uosc Cupertino 定制界面）";
  };

  config = lib.mkIf (cfg.enable && guiCfg.enable) {
    # 不用 programs.mpv：那个模块会自己生成 mpv/mpv.conf 与 mpv/input.conf，
    # 与下面整目录的软链撞同一路径，HM 激活时会判冲突。
    home.packages = [ pkgs.mpv ];

    # 图标字体：uosc 按字体名查找，必须进 fontconfig 搜索路径
    xdg.dataFile."fonts/CupertinoIcons.ttf".source = ./mpv/fonts/CupertinoIcons.ttf;

    xdg.configFile."mpv".source = ./mpv;
  };
}
