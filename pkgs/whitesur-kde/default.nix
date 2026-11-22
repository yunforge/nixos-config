# WhiteSur-kde（vinceliuice，macOS Big Sur 风格）
#
# nixpkgs 的 `whitesur-kde` 钉在 2024-11-18 的源码快照，缺少上游 2024-12-12
# 才加入的 Plasma 6 注销界面（`plasma/look-and-feel/*/contents/logout`），
# 而本轮外观对齐要用到它。这里只把 `src` 换成该提交，其余打包步骤沿用
# nixpkgs：`install.sh` 装外观组件，`sddm/install.sh` 装登录主题。
#
# 为什么不跟 master：2024-12-12 之后的提交只改 Liquid 变体与面板贴图，
# 与仓库声明的 WhiteSur 外观无关；钉在「刚好带上 logout」的提交，避免把无关的
# 桌面上游改动一起带进来。升级时确认目标提交仍包含
# `plasma/look-and-feel/com.github.vinceliuice.WhiteSur{,-dark}/contents/logout`。
{
  lib,
  whitesur-kde,
  fetchFromGitHub,
}:

whitesur-kde.overrideAttrs (old: {
  version = "unstable-2024-12-12";

  src = fetchFromGitHub {
    owner = "vinceliuice";
    repo = "WhiteSur-kde";
    rev = "5013507cce060720efebd4c58b019cde2f44c9ec";
    hash = "sha256-iBifdm70puTRjher2xUrc/6dkc6618T5MHaaPEFosOk=";
  };

  meta = (old.meta or { }) // {
    description = "MacOS Big Sur like theme for KDE Plasma";
    homepage = "https://github.com/vinceliuice/WhiteSur-kde";
    license = lib.licenses.gpl3Plus;
  };
})
