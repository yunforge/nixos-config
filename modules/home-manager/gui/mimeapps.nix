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
  cfg = config.mengw.gui;
in
{
  config = lib.mkIf cfg.enable {
    xdg.mimeApps.enable = true;

    # 语法要点：值是「且仅有一个元素」的列表，get_supported_types 才会把它当默认程序；
    # 单元素写了会被 GLib 读成 NULL。HM 会把它序列化成 `key=app;`。
    xdg.mimeApps.defaultApplications = {
      "x-scheme-handler/clash" = "clash-verge.desktop";
      "x-scheme-handler/clash-verge" = "clash-verge.desktop";
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
      "x-scheme-handler/jetbrains" = "jetbrainsd.desktop";
      "x-scheme-handler/chrome" = "zen-beta.desktop";
      "application/x-extension-htm" = "zen-beta.desktop";
      "application/x-extension-html" = "zen-beta.desktop";
      "application/x-extension-shtml" = "zen-beta.desktop";
      "application/xhtml+xml" = "brave-browser.desktop";
      "application/x-extension-xhtml" = "zen-beta.desktop";
      "application/x-extension-xht" = "zen-beta.desktop";
      "x-scheme-handler/x-github-client" = "github-desktop.desktop";
      "x-scheme-handler/x-github-desktop-dev-auth" = "github-desktop.desktop";
      "application/epub+zip" = "com.github.johnfactotum.Foliate.desktop";
      "video/mp4" = "zen-beta.desktop";
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
    };

    # Added Associations 只影响「用哪个打开」候选列表，用真实 .desktop 且保留多元素列表。
    xdg.mimeApps.associations.added = {
      "x-scheme-handler/mailto" = [ "thunderbird.desktop" ];
      "x-scheme-handler/mid" = [ "thunderbird.desktop" ];
      "x-scheme-handler/clash" = [ "clash-verge.desktop" ];
      "x-scheme-handler/clash-verge" = [ "clash-verge.desktop" ];
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
      "application/epub+zip" = [ "com.github.johnfactotum.Foliate.desktop" ];
      "x-scheme-handler/http" = [
        "zen-beta.desktop"
        "brave-browser.desktop"
      ];
      "x-scheme-handler/https" = [
        "zen-beta.desktop"
        "brave-browser.desktop"
      ];
      "video/mp4" = [ "zen-beta.desktop" ];
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
      "x-scheme-handler/chrome" = [ "zen-beta.desktop" ];
      "image/x-nikon-nef" = [ "com.interversehq.qView.desktop" ];
      "text/x-c++src" = [ "org.gnome.TextEditor.desktop" ];
    };
  };
}
