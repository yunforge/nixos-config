# MIME 默认程序 / 关联
#
# 为什么整份都由 HM 托管：Thunderbird 启动时（打包默认 mail.shell.checkDefaultClient=true）
# 会把邮件类默认程序抢成自己，走 libgio 的 g_app_info_set_as_default_for_type —— 该函数
# 先 mkstemp 生成一个新的 ~/.local/share/applications/userapp-Thunderbird-XXXXXX.desktop，
# 再写 ~/.config/mimeapps.list。mimeapps.list 一旦成为 HM 的只读符号链接，写配置那步会
# 失败，但 userapp 文件在之前就已落地；真正止血的是下面 user.js 里的 checkDefaultClient=false
# （见 productivity.nix），这里负责把「默认程序」声明式地钉死。
#
# 注意：HM 的 xdg.mimeApps 是整份生成、覆盖式写入。原 ~/.config/mimeapps.list 里
# 由各应用 GUI「设为默认」积累的关联必须全部搬进来，否则会被清掉。首次 switch 时
# 旧文件会被备份成 mimeapps.list.hm-bak。
{
  lib,
  config,
  ...
}:
let
  cfg = config.myHome.desktop;

  # 视频类 MIME → 默认交给 mpv（mp4 单独处理，见下）。
  #
  # 名字取 shared-mime-info 的**规范名**：GLib 查 [Default Applications] 是按精确字符串
  # 查的（实测 g_app_info_get_default_for_type 只认字面 key），所以名字必须和
  # g_content_type_guess 猜出来的一致；同时带上历史上用过的旧名，免得 shared-mime-info
  # 换版本后文件名对不上、关联静默失效。
  #
  # 已实测（GLib 2.88.3 + shared-mime-info 2.5.1）各扩展名实际猜出的类型：
  #   .mkv→video/matroska  .avi→video/vnd.avi  .wmv→video/x-ms-wmv
  #   .asf→application/vnd.ms-asf  .rm/.rmvb→application/vnd.rn-realmedia
  #   .mov→video/quicktime  .webm→video/webm  .flv→video/x-flv
  #   .3gp→video/3gpp  .ogv→video/ogg  .ogm→video/x-ogm+ogg
  #   .ts/.mts/.m2ts→video/mp2t  .mpg/.vob→video/mpeg  .dv→video/dv
  #   .mp4/.m4v/.f4v→video/mp4
  # 音频类不动（仍归 g4music），mpv 虽也声明了 audio/* 的 MimeType，但不在这里设默认。
  videoMimes = [
    "video/x-m4v" # mp4v 的旧名
    "video/matroska" # mkv / mk3d
    "video/x-matroska" # mkv 的旧名
    "video/webm"
    "video/quicktime" # mov / qt
    "video/vnd.avi" # avi / avf / divx
    "video/x-msvideo" # avi 的旧名
    "video/x-ms-wmv" # wmv
    "application/vnd.ms-asf" # asf
    "video/x-ms-asf" # asf 的旧名
    "video/mpeg" # mpg / mpeg / vob
    "video/x-flv"
    "video/3gpp"
    "video/3gpp2"
    "video/ogg"
    "video/x-ogm+ogg"
    "video/mp2t" # ts / mts / m2ts
    "video/dv"
    "application/vnd.rn-realmedia" # rm / rmvb
  ];
in
{
  config = lib.mkIf cfg.enable {
    xdg.mimeApps.enable = true;

    # 语法要点：值是「且仅有一个元素」的列表，get_supported_types 才会把它当默认程序；
    # 单元素写了会被 GLib 读成 NULL。HM 会把它序列化成 `key=app;`。
    xdg.mimeApps.defaultApplications = {
      # 代理客户端换成 FlClash（见 media.nix）。它的 .desktop 声明了
      # clash / clashmeta / flclash 三个 scheme；clash-verge 那个是旧客户端的
      # 专属 scheme，留着映射到 FlClash，免得老链接点不开。
      "x-scheme-handler/clash" = "flclash.desktop";
      "x-scheme-handler/clashmeta" = "flclash.desktop";
      "x-scheme-handler/flclash" = "flclash.desktop";
      "x-scheme-handler/clash-verge" = "flclash.desktop";
      "x-scheme-handler/mailto" = "thunderbird.desktop";
      "message/rfc822" = "thunderbird.desktop";
      "x-scheme-handler/mid" = "thunderbird.desktop";
      "application/pdf" = "org.gnome.Papers.desktop";
      "application/x-subrip" = "org.gnome.TextEditor.desktop";
      "x-scheme-handler/claude-cli" = "claude-code-url-handler.desktop";
      "x-scheme-handler/siyuan" = "siyuan.desktop";
      "text/html" = "brave-browser.desktop";
      "x-scheme-handler/http" = "brave-browser.desktop";
      "x-scheme-handler/https" = "brave-browser.desktop";
      "x-scheme-handler/about" = "brave-browser.desktop";
      "x-scheme-handler/unknown" = "brave-browser.desktop";
      "image/jpeg" = "com.interversehq.qView.desktop";
      "text/plain" = "org.gnome.TextEditor.desktop";
      "x-scheme-handler/net.thunderbird" = "thunderbird.desktop";
      "image/webp" = "com.interversehq.qView.desktop";
      "x-scheme-handler/tg" = "org.telegram.desktop.desktop";
      "x-scheme-handler/tonsite" = "org.telegram.desktop.desktop";
      "application/x-zerosize" = "typora.desktop";
      "text/markdown" = "typora.desktop";
      "x-scheme-handler/jetbrains" = "jetbrainsd.desktop";
      "x-scheme-handler/chrome" = "brave-browser.desktop";
      "application/x-extension-htm" = "brave-browser.desktop";
      "application/x-extension-html" = "brave-browser.desktop";
      "application/x-extension-shtml" = "brave-browser.desktop";
      "application/xhtml+xml" = "brave-browser.desktop";
      "application/x-extension-xhtml" = "brave-browser.desktop";
      "application/x-extension-xht" = "brave-browser.desktop";
      "x-scheme-handler/x-github-client" = "github-desktop.desktop";
      "x-scheme-handler/x-github-desktop-dev-auth" = "github-desktop.desktop";
      "application/epub+zip" = "com.github.johnfactotum.Foliate.desktop";
      "video/mp4" = "mpv.desktop";
      "image/png" = "com.interversehq.qView.desktop";
      "audio/x-vorbis+ogg" = "com.github.neithern.g4music.desktop";
      "audio/wav" = "com.github.neithern.g4music.desktop";
      "audio/webm" = "com.github.neithern.g4music.desktop";
      "audio/x-aac" = "com.github.neithern.g4music.desktop";
      "audio/x-aiff" = "com.github.neithern.g4music.desktop";
      "audio/x-ape" = "com.github.neithern.g4music.desktop";
      "audio/x-flac" = "com.github.neithern.g4music.desktop";
      "audio/x-it" = "com.github.neithern.g4music.desktop";
      "audio/x-m4a" = "com.github.neithern.g4music.desktop";
      "audio/x-m4b" = "com.github.neithern.g4music.desktop";
      "audio/x-matroska" = "com.github.neithern.g4music.desktop";
      "audio/x-mod" = "com.github.neithern.g4music.desktop";
      "audio/x-mp1" = "com.github.neithern.g4music.desktop";
      "audio/x-mp2" = "com.github.neithern.g4music.desktop";
      "audio/x-mp3" = "com.github.neithern.g4music.desktop";
      "audio/x-mpg" = "com.github.neithern.g4music.desktop";
      "audio/x-mpeg" = "com.github.neithern.g4music.desktop";
      "audio/x-ms-asf" = "com.github.neithern.g4music.desktop";
      "audio/x-ms-asx" = "com.github.neithern.g4music.desktop";
      "audio/x-ms-wax" = "com.github.neithern.g4music.desktop";
      "audio/x-ms-wma" = "com.github.neithern.g4music.desktop";
      "audio/x-musepack" = "com.github.neithern.g4music.desktop";
      "audio/x-opus+ogg" = "com.github.neithern.g4music.desktop";
      "audio/x-pn-aiff" = "com.github.neithern.g4music.desktop";
      "audio/x-pn-au" = "com.github.neithern.g4music.desktop";
      "audio/x-pn-realaudio" = "com.github.neithern.g4music.desktop";
      "audio/x-pn-realaudio-plugin" = "com.github.neithern.g4music.desktop";
      "audio/x-pn-wav" = "com.github.neithern.g4music.desktop";
      "audio/x-pn-windows-acm" = "com.github.neithern.g4music.desktop";
      "audio/x-realaudio" = "com.github.neithern.g4music.desktop";
      "audio/x-real-audio" = "com.github.neithern.g4music.desktop";
      "audio/x-s3m" = "com.github.neithern.g4music.desktop";
      "audio/x-sbc" = "com.github.neithern.g4music.desktop";
      "audio/x-shorten" = "com.github.neithern.g4music.desktop";
      "audio/x-speex" = "com.github.neithern.g4music.desktop";
      "audio/x-stm" = "com.github.neithern.g4music.desktop";
      "audio/x-tta" = "com.github.neithern.g4music.desktop";
      "audio/x-wav" = "com.github.neithern.g4music.desktop";
      "audio/x-wavpack" = "com.github.neithern.g4music.desktop";
      "audio/x-vorbis" = "com.github.neithern.g4music.desktop";
      "audio/x-xm" = "com.github.neithern.g4music.desktop";
      "audio/x-mpegurl" = "com.github.neithern.g4music.desktop";
      "audio/x-scpls" = "com.github.neithern.g4music.desktop";
      "image/x-nikon-nef" = "com.interversehq.qView.desktop";
      "text/x-c++src" = "org.gnome.TextEditor.desktop";
      "x-scheme-handler/magpie" = "magpie.desktop";
    }
    # 视频类默认程序统一交给 mpv（桌面条目由 mpv 包提供，经 HM 的 user-environment
    # 落到 /etc/profiles/per-user/<user>/share/applications，在 XDG_DATA_DIRS 里可见，
    # 无需再往 ~/.local/share/applications 塞一份）。
    #
    # 用 mpv.desktop 而不是 umpv.desktop（mpv 包自带的单实例包装）：mpv.desktop 的
    # Exec 是 `mpv --player-operation-mode=pseudo-gui`，该模式只在「配置文件里没设过」
    # 的选项上套用 builtin-pseudo-gui，所以本仓库 mpv.conf 的 screenshot-directory
    # 等定制都还在；umpv 走的是 `--profile=builtin-pseudo-gui`，会**覆盖**配置文件，
    # 截图目录被改回 ~~desktop/、还会强制开窗。想用单实例行为可在 Nautilus 里
    # 「打开方式」选 umpv（它已在候选列表里）。
    // lib.listToAttrs (
      map (mime: {
        name = mime;
        value = "mpv.desktop";
      }) videoMimes
    );

    # Added Associations 只影响「用哪个打开」候选列表，用真实 .desktop 且保留多元素列表。
    xdg.mimeApps.associations.added = {
      "x-scheme-handler/mailto" = [ "thunderbird.desktop" ];
      "x-scheme-handler/mid" = [ "thunderbird.desktop" ];
      "x-scheme-handler/clash" = [ "flclash.desktop" ];
      "x-scheme-handler/clashmeta" = [ "flclash.desktop" ];
      "x-scheme-handler/flclash" = [ "flclash.desktop" ];
      "x-scheme-handler/clash-verge" = [ "flclash.desktop" ];
      "application/pdf" = [ "org.gnome.Papers.desktop" ];
      "application/x-subrip" = [ "org.gnome.TextEditor.desktop" ];
      "image/jpeg" = [ "com.interversehq.qView.desktop" ];
      "text/plain" = [ "org.gnome.TextEditor.desktop" ];
      "x-scheme-handler/net.thunderbird" = [ "thunderbird.desktop" ];
      "message/rfc822" = [ "thunderbird.desktop" ];
      "image/webp" = [ "com.interversehq.qView.desktop" ];
      "x-scheme-handler/tg" = [ "org.telegram.desktop.desktop" ];
      "x-scheme-handler/tonsite" = [ "org.telegram.desktop.desktop" ];
      "application/x-zerosize" = [ "typora.desktop" ];
      "text/markdown" = [
        "typora.desktop"
        "org.gnome.TextEditor.desktop"
      ];
      "application/epub+zip" = [ "com.github.johnfactotum.Foliate.desktop" ];
      "x-scheme-handler/http" = [
        "brave-browser.desktop"
        "zen-beta.desktop"
      ];
      "x-scheme-handler/https" = [
        "brave-browser.desktop"
        "zen-beta.desktop"
      ];
      "video/mp4" = [
        "mpv.desktop"
        "zen-beta.desktop"
      ];
      "image/png" = [ "com.interversehq.qView.desktop" ];
      "application/xhtml+xml" = [
        "brave-browser.desktop"
        "zen-beta.desktop"
      ];
      "text/html" = [
        "brave-browser.desktop"
        "zen-beta.desktop"
      ];
      "audio/wav" = [ "com.github.neithern.g4music.desktop" ];
      "audio/webm" = [ "com.github.neithern.g4music.desktop" ];
      "audio/x-aac" = [ "com.github.neithern.g4music.desktop" ];
      "audio/x-aiff" = [ "com.github.neithern.g4music.desktop" ];
      "audio/x-ape" = [ "com.github.neithern.g4music.desktop" ];
      "audio/x-flac" = [ "com.github.neithern.g4music.desktop" ];
      "audio/x-it" = [ "com.github.neithern.g4music.desktop" ];
      "audio/x-m4a" = [ "com.github.neithern.g4music.desktop" ];
      "audio/x-m4b" = [ "com.github.neithern.g4music.desktop" ];
      "audio/x-matroska" = [ "com.github.neithern.g4music.desktop" ];
      "audio/x-mod" = [ "com.github.neithern.g4music.desktop" ];
      "audio/x-mp1" = [ "com.github.neithern.g4music.desktop" ];
      "audio/x-mp2" = [ "com.github.neithern.g4music.desktop" ];
      "audio/x-mp3" = [ "com.github.neithern.g4music.desktop" ];
      "audio/x-mpg" = [ "com.github.neithern.g4music.desktop" ];
      "audio/x-mpeg" = [ "com.github.neithern.g4music.desktop" ];
      "audio/x-ms-asf" = [ "com.github.neithern.g4music.desktop" ];
      "audio/x-ms-asx" = [ "com.github.neithern.g4music.desktop" ];
      "audio/x-ms-wax" = [ "com.github.neithern.g4music.desktop" ];
      "audio/x-ms-wma" = [ "com.github.neithern.g4music.desktop" ];
      "audio/x-musepack" = [ "com.github.neithern.g4music.desktop" ];
      "audio/x-opus+ogg" = [ "com.github.neithern.g4music.desktop" ];
      "audio/x-pn-aiff" = [ "com.github.neithern.g4music.desktop" ];
      "audio/x-pn-au" = [ "com.github.neithern.g4music.desktop" ];
      "audio/x-pn-realaudio" = [ "com.github.neithern.g4music.desktop" ];
      "audio/x-pn-realaudio-plugin" = [ "com.github.neithern.g4music.desktop" ];
      "audio/x-pn-wav" = [ "com.github.neithern.g4music.desktop" ];
      "audio/x-pn-windows-acm" = [ "com.github.neithern.g4music.desktop" ];
      "audio/x-realaudio" = [ "com.github.neithern.g4music.desktop" ];
      "audio/x-real-audio" = [ "com.github.neithern.g4music.desktop" ];
      "audio/x-s3m" = [ "com.github.neithern.g4music.desktop" ];
      "audio/x-sbc" = [ "com.github.neithern.g4music.desktop" ];
      "audio/x-shorten" = [ "com.github.neithern.g4music.desktop" ];
      "audio/x-speex" = [ "com.github.neithern.g4music.desktop" ];
      "audio/x-stm" = [ "com.github.neithern.g4music.desktop" ];
      "audio/x-tta" = [ "com.github.neithern.g4music.desktop" ];
      "audio/x-wav" = [ "com.github.neithern.g4music.desktop" ];
      "audio/x-wavpack" = [ "com.github.neithern.g4music.desktop" ];
      "audio/x-vorbis" = [ "com.github.neithern.g4music.desktop" ];
      "audio/x-xm" = [ "com.github.neithern.g4music.desktop" ];
      "audio/x-mpegurl" = [ "com.github.neithern.g4music.desktop" ];
      "audio/x-scpls" = [ "com.github.neithern.g4music.desktop" ];
      "x-scheme-handler/chrome" = [ "brave-browser.desktop" ];
      "image/x-nikon-nef" = [ "com.interversehq.qView.desktop" ];
      "text/x-c++src" = [ "org.gnome.TextEditor.desktop" ];
    }
    // lib.listToAttrs (
      map (mime: {
        name = mime;
        value = [ "mpv.desktop" ];
      }) videoMimes
    );
  };
}
