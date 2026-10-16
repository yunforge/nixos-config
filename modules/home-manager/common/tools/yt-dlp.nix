# yt-dlp — 视频/音频下载器
#
# settings 由 HM 模块渲染成 $XDG_CONFIG_HOME/yt-dlp/config（长选项形式，布尔 = 有无
# --no- 前缀，见 home-manager/modules/programs/yt-dlp.nix）。包也由该模块提供，
# 故 default.nix 的 home.packages 里不再单独列 yt-dlp。
{
  lib,
  config,
  pkgs,
  ...
}:
let
  cfg = config.mengw.cli.tools.yt-dlp;
  cliCfg = config.mengw.cli;
in
{
  options.mengw.cli.tools.yt-dlp.enable = lib.mkOption {
    type = lib.types.bool;
    default = true;
    description = "启用 yt-dlp 及下载配置";
  };

  config = lib.mkIf (cfg.enable && cliCfg.enable) {
    programs.yt-dlp = {
      enable = true;
      # 默认下载最佳画质
      # 自动合并为 mp4
      # 保存到统一目录
      # 嵌入元数据、封面、章节
      # 字幕默认下载
      # 单视频 URL 不意外下载整个 playlist
      # 网络波动时自动重试
      settings = {
        # 下载根目录（yt-dlp 内部对 --paths 做 expanduser，~ 可用）。
        # output 相对此目录 → ~/Videos/yt-dlp/<uploader>/...
        paths = "~/Videos/yt-dlp";
        output = "%(title)s.%(ext)s";

        # 画质：优先 H.264(avc1)+AAC(mp4a)，落 mp4 容器。
        # 不能用 bestvideo*+bestaudio：YouTube 现在把 AV1 塞进 mp4 容器（format 399，
        # ext 也是 mp4），故 ext=mp4 挡不住 AV1；而部分播放器只能解 H.264，AV1 会
        # 「只有音频」。这里显式按 vcodec/acodec 挑，兼容性优先于画质。
        # 回落链：/b[vcodec^=avc1]（合流 H.264）→ /b（最坏情况下退到任意可用）。
        format = "bv*[vcodec^=avc1]+ba[acodec^=mp4a]/b[vcodec^=avc1]/b";
        merge-output-format = "mp4";

        # 元数据
        embed-metadata = true;
        embed-thumbnail = true;
        embed-chapters = true;

        # 字幕
        write-subs = true;
        write-auto-subs = true;
        sub-langs = "en.*,zh-Hans,zh-Hant";

        # 默认只下载指定的视频
        no-playlist = true;

        # 认证：YouTube 反爬要求登录态，直接读 Brave 的 cookie 库（Chrome 系会
        # 复制一份再读，Brave 开着也能用），不落盘明文 cookies.txt。保持 Brave
        # 里 YouTube 登录即可。
        #
        # 必须带 +gnomekeyring：Brave 的 cookie 是 v11（用 gnome-keyring 解锁的
        # 「Safe Storage」密钥加密）。yt-dlp 默认按桌面环境推 keyring，而 niri 不在
        # 它认识的 DE 名单里 → 归为 OTHER → 选 BASICTEXT → 取不到 v11 密钥 →
        # 0 cookies → YouTube 报「Sign in to confirm you're not a bot」。后缀强制
        # 走 gnome-keyring。若将来换 KDE，改成 brave+kwallet6。
        cookies-from-browser = "brave+gnomekeyring";

        # 网络重试
        retries = 10;
        fragment-retries = 10;
        retry-sleep = "exp=1:20";

        # 文件处理
        no-overwrites = true;
        continue = true;
        trim-filenames = 180;
      };
    };
  };
}
