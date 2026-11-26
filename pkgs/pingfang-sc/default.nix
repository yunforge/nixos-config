# PingFang SC（苹方-简）—— 苹果的简体中文字体
#
# nixpkgs 不会收录（苹果 SLFA 禁止再分发），故自维护。源头是本仓库作者 fork 的
# https://github.com/yunforge/Font-PingFang（上游 Pal3love/Font-PingFang，2019 年
# 的镜像，内容即 macOS 自带那份 OTF）。
#
# 为什么用 fetchFromGitHub 而不是逐文件 fetchurl：
#   - 单一 rev 钉住整批 6 个字重，升级只改一处；
#   - 仓库里 HK/ 目录与 SC/PingFang-SC-Regular.ttf 不要：
#       * HK 是繁体，本机不用；
#       * 那个 TTF 是 2015 年的旧版本（fontversion 78643，OTF 是 137625），
#         家族名同样是 PingFang SC，装了会和 OTF 撞家族、被 fontconfig 随机命中。
#     fetchFromGitHub 会把整个仓库（含 HK，约 150 MB）拉进 store 一次，但
#     产物 $out 只含 SC 的 6 个 OTF（约 81 MB）—— 多出来的 70 MB 是源码树，
#     不进任何主机的闭包，只在评估时下载一次。
#
# 与本机 ~/.local/share/fonts/PingFangSC/ 里手动放的那份逐字节相同（6 个文件
# sha256 全等，2026-11-27 核对），故切换后视觉零变化。
#
# 升级：这个仓库是静态镜像，不跟版本。上游若有新字重 / 新 rev，改 rev 后用
#   nix build .#pingfang-sc --no-write-lock-file 2>&1 | grep 'got:'
# 取新哈希。
{
  lib,
  stdenvNoCC,
  fetchFromGitHub,
}:

stdenvNoCC.mkDerivation {
  pname = "pingfang-sc";
  version = "unstable-2019-10-07";

  src = fetchFromGitHub {
    owner = "yunforge";
    repo = "Font-PingFang";
    rev = "497d8dfbbf3be2781c08846f35bd3b7ab5a494ba";
    hash = "sha256-y2zklmqG/uQKctWW8NrnZ8+DSF8k77Zl2JwqiZkpUKM=";
  };

  # 字体不是可执行文件，不用 build 来回；也避免 stdenv 的 fixup 阶段对 OTF 跑
  # strip / patchelf。
  dontBuild = true;
  dontFixup = true;

  installPhase = ''
    runHook preInstall

    mkdir -p $out/share/fonts/opentype/pingfang-sc
    install -m644 SC/PingFangSC_*.otf $out/share/fonts/opentype/pingfang-sc/

    runHook postInstall
  '';

  meta = {
    description = "PingFang SC, Apple's Simplified Chinese system font";
    homepage = "https://github.com/yunforge/Font-PingFang";
    # 苹果字体只随 macOS 授权，不可再分发；自用可以，公开 flake 输出不要依赖此包。
    license = lib.licenses.unfree;
    platforms = lib.platforms.all;
  };
}
