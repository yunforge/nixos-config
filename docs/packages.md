# 自维护包（nixpkgs 未收录）

`pkgs/` 下是**仓库自己打包**的应用与主题：nixpkgs 没有，或 nixpkgs 的版本不满足需求。
它们的版本号钉死在仓库里，`nix flake update` **不会**带动它们 —— 只有这里列出的包需要手工升级。

单一注入点是 `overlays/default.nix`（三处消费：NixOS `nixpkgs.overlays`、darwin
`nixpkgs.overlays`、flake 输出的 `packages.*`）。**加包 / 改包先看这里，别在模块里另起一套。**

## 清单

版本核对于 2026-11-26（其余包升到上游最新；FlClash 故意钉在 0.9.3，原因见 `docs/quirks.md`）。

| 属性名 | 上游 | 钉法 | 当前钉住 | 上游最新 | 状态 |
|--------|------|------|----------|----------|------|
| `magpie` / `magpie-cli` | [yetone/magpie](https://github.com/yetone/magpie) | tag | `v0.1.4808` | `v0.1.4808` | 最新 |
| `mcpp-m` | [mcpp-community/mcpp](https://github.com/mcpp-community/mcpp) | release 资产 | `2026.11.24.1` | `2026.11.24.1` | 最新 |
| `flclash` | [chen08209/FlClash](https://github.com/chen08209/FlClash) | release 资产（deb） | `0.9.3` | `0.9.4` | 回退（0.9.4 渲染回归，见 `docs/quirks.md`） |
| `dalibre` | [djyde/dalibre](https://github.com/djyde/dalibre) | release 资产（tar.gz） | `0.8.0` | `0.8.0` | 最新（unfree：上游无 LICENSE 文件） |
| `pulse` | [egoist/pulse-feedback](https://github.com/egoist/pulse-feedback) | release 资产（tar.gz） | `0.1.31` | `0.1.31` | 最新（unfree：只有反馈仓库、无 LICENSE 文件） |
| `misterdownloadmanager` | [anefzaoui/misterdownloadmanager](https://github.com/anefzaoui/misterdownloadmanager) | release 资产（deb） | `0.5.2` | `0.5.2` | 最新（上游仅发 x86_64-linux 的 Linux 资产） |
| `whitesur-kde` | [vinceliuice/WhiteSur-kde](https://github.com/vinceliuice/WhiteSur-kde) | commit（覆盖 nixpkgs 快照） | `5013507`（2024-12-12） | main 远新于此 | 故意钉住：只取「补上注销界面」的最小提交 |
| `whitesur-plasma-splash` | 同上（子目录 `plasma/look-and-feel/`） | 跟随 `whitesur-kde` | 同上 | — | 派生包，不用单独升级 |
| `whitesur-sddm-theme` | 同上（子目录 `sddm/WhiteSur-6.2`） | 跟随 `whitesur-kde` | 同上 | — | 派生包，不用单独升级 |
| `mactahoe-gtk-theme` | [vinceliuice/MacTahoe-gtk-theme](https://github.com/vinceliuice/MacTahoe-gtk-theme) | commit（tag 指向） | `0aa2a2b`（tag `2026-09-10`） | 同一 commit | 惰性保留：2026-11-22 起不再被引用 |
| `mactahoe-icon-theme` | [vinceliuice/MacTahoe-icon-theme](https://github.com/vinceliuice/MacTahoe-icon-theme) | commit（tag 指向） | `839848b`（tag `2026-09-10`） | 同一 commit | 惰性保留：同上 |
| `mactahoe-kvantum` | [vinceliuice/MacTahoe-kde](https://github.com/vinceliuice/MacTahoe-kde) | commit（main，无 tag） | `cbf6a1f` | 同一 commit | 惰性保留：同上 |
| `mactahoe-sddm-theme` | [vinceliuice/MacTahoe-kde](https://github.com/vinceliuice/MacTahoe-kde)（子目录 `sddm/`） | commit（main，无 tag） | `cbf6a1f` | 同一 commit | 惰性保留：同上 |
| `pingfang-sc` | [yunforge/Font-PingFang](https://github.com/yunforge/Font-PingFang)（本人 fork 的 macOS 苹方镜像，只取 `SC/*.otf`） | commit（静态镜像，不打 tag） | `497d8df`（2019-10-07） | 同一 commit | 最新（unfree：苹果字体不可再分发，自用） |
| `windows-vm-media` | virtio-win（nixpkgs）+ WinApps `oem/` | 跟随 flake 输入 | — | — | 不手工升级 |

各包的**为什么这么打包**写在 `pkgs/<包名>/default.nix` 文件头，这里不重复。

### `flclash` 为什么是「nixpkgs 曾经有、后来移除」

nixpkgs 在 26.05 分支收录过 `flclash`（0.8.92），2026-08-17 以「用户少 + 无人维护」
为由从 master 移除，`pkgs/top-level/aliases.nix` 里留了 throw 的墓碑。本仓库的
nixpkgs 输入跟 master，`nix flake update` 不会把它带回来——要就得自维护。

烂掉的是 nixpkgs 那份**打包**（源码构建，每个上游版本要同步 `pubspec.lock.json`、
`git-hashes.json`、core 的 `vendorHash` 三份钉子），不是软件：上游 2026-10-24 发了
v0.9.2，5.9 万 star，仍在活跃开发。故本包改走上游预编译 deb，升级只改版本 + 哈希。

消费方（改包时确认影响面）：

| 包 | 装在哪 |
|----|--------|
| `magpie` | 同上（desktop/laptop 桌面版）；`magpie-cli` 在 `hosts/wsl/default.nix` |
| `mcpp-m` | `modules/home-manager/dev/languages/cpp.nix`（所有 Linux 主机 + macbook） |
| `flclash` | `modules/home-manager/gui/apps/linux/media.nix`（代理客户端，取代 clash-verge-rev） |
| `dalibre` | `modules/home-manager/gui/apps/linux/productivity.nix`（calibre 书库管理器） |
| `pulse` | `modules/home-manager/gui/apps/linux/utilities.nix`（系统活动监视器，取代 mission-center） |
| `misterdownloadmanager` | `modules/home-manager/gui/apps/linux/utilities.nix`（下载管理器） |
| `whitesur-kde` | `modules/home-manager/gui/desktop/linux/kde-appearance.nix`（裁出 aurorae / 配色 / 桌面主题 / Kvantum，并取源码里的 logout） |
| `whitesur-plasma-splash` | `modules/nixos/desktop/sddm.nix`（仅 Plasma 主机，装进系统 profile 供 ksplashqml 读取） |
| `whitesur-sddm-theme` | `modules/nixos/desktop/sddm.nix`（SDDM 主题 `WhiteSur-dark`） |
| `mactahoe-*` | 2026-11-22 起无消费方；定义与 overlay 惰性保留，便于回退 |
| `pingfang-sc` | `modules/nixos/core/locale.nix`（`fonts.packages`，所有 Linux 主机的界面主字体；家族名常量 `myLib.theme.fontSans`） |
| `windows-vm-media` | `modules/nixos/virtualization`（`mySystem.virtualization`） |

不在本清单里的东西：nixpkgs 里的一切（跟着 `nix flake update` 走）、flake inputs
（nixpkgs / nur / winapps / home-manager / noctalia / msime / zen-browser）。

## 「更新系统」时的固定动作

用户说**「更新系统」**时，除了刷 flake 输入，还要按本清单逐个查上游并升级落后的包：

```bash
# 1. 刷新 flake 输入（nixpkgs / HM / noctalia / winapps …）
nix flake update

# 2. 查各包上游（命令见下面「查上游最新版本」一节），有新版就按钉法升级

# 3. 验证
nix fmt
nix flake check
nix build --dry-run .#magpie .#magpie-cli .#mcpp-m .#flclash .#dalibre .#pulse \
  .#misterdownloadmanager .#whitesur-kde .#whitesur-plasma-splash .#whitesur-sddm-theme \
  .#mactahoe-gtk-theme .#mactahoe-icon-theme .#mactahoe-kvantum .#mactahoe-sddm-theme \
  .#windows-vm-media
nix build --dry-run .#nixosConfigurations.desktop.config.system.build.toplevel
```

升级提交单独成 commit（`feat(<scope>): 升级到 <版本>`，见 `git log --oneline` 惯例），
不要和 flake 输入刷新混在一起 —— 出问题时能单独回退。

## 查上游最新版本

```bash
# 打 tag 的仓库（magpie / MacTahoe-*）
git ls-remote --tags --refs https://github.com/<owner>/<repo> \
  | sed 's#.*refs/tags/##' | sort -V | tail -3

# 走 GitHub Release 的（mcpp / flclash）：看 latest 跳转到哪个 tag
curl -sI https://github.com/<owner>/<repo>/releases/latest | grep -i '^location'

# 跟 main 走的（MacTahoe-kde）：HEAD 即最新
git ls-remote https://github.com/<owner>/<repo> HEAD

# WhiteSur-kde 例外：故意钉在 5013507（只比 nixpkgs 快照多一个注销界面）。
# 升级前先确认上游未引入仓库未声明的面，且 kde-appearance.nix 的裁剪规则仍匹配。
```

## 按钉法升级

哈希统一用 `nix flake prefetch` 取（与 `fetchFromGitHub` 的 `stripRoot = true` 同源，
结果与包里钉的哈希逐字一致，不必再靠 `lib.fakeHash` 试错）：

```bash
nix flake prefetch --json github:<owner>/<repo>/<tag 或 rev> | jq -r .hash
```

### tag 钉法（`magpie`）

```nix
version = "0.1.3449";   # ① 改版本
```

```bash
# ② src 哈希
nix flake prefetch --json github:yetone/magpie/v0.1.3449 | jq -r .hash
```

- `vendorHash`（magpie）只在 `go.mod`+`go.sum` 变化时需要重算，同样填
  `lib.fakeHash` 跑一次构建，取报错里的 `got:`。
- **不要**用 `magpie update` / `mcpp self update`：它们会替换自己的二进制，store 只读必然失败。

### release 资产（`mcpp-m`）

```bash
# ① 上游为每个资产发布 .sha256（hex），取来转 SRI
curl -sL https://github.com/mcpp-community/mcpp/releases/download/v<版本>/mcpp-<版本>-linux-x86_64.tar.gz.sha256
nix hash convert --hash-algo sha256 --to sri <hex>
```

```nix
version = "<版本>";
sources = {
  x86_64-linux   = { asset = "linux-x86_64";   hash = "sha256-…"; };
  aarch64-linux  = { asset = "linux-aarch64";  hash = "sha256-…"; };
  aarch64-darwin = { asset = "macosx-arm64";   hash = "sha256-…"; };
};
```

三个平台都要更新（上游只发这三个；其余平台由包内 `throw` 显式报错）。

### release 资产（deb，`flclash`）

上游每个版本发一组预编译产物（deb / AppImage / rpm / dmg / exe）与一份
`SHA256SUMS`，本包只取 Linux 的两个 deb：

```nix
version = "0.9.3";

sources = {
  x86_64-linux  = { asset = "amd64"; hash = "sha256-…"; };
  aarch64-linux = { asset = "arm64"; hash = "sha256-…"; };
};
```

```bash
# ① 上游 SHA256SUMS（十六进制）转 SRI
curl -sL https://github.com/chen08209/FlClash/releases/download/v<版本>/SHA256SUMS \
  | grep 'linux-\(amd64\|arm64\)\.deb'
nix hash convert --hash-algo sha256 --to sri <hex>
```

- 资产名规则是 `FlClash-<版本>-linux-<amd64|arm64>.deb`；上游若改命名规则，构建会以
  404 失败，照报错改 `url` 即可。
- 升级只改 `version` + 两个哈希，**不需要**重算别的东西（不走源码构建，没有
  pubspec.lock / vendorHash 那三份钉子）。

### release 资产（tar.gz，`dalibre`）

与 `flclash` 同型：上游发预编译 tar.gz + `SHA256SUMS`，只取 Linux 的两个：

```nix
version = "0.2.2";

sources = {
  x86_64-linux  = { asset = "amd64"; hash = "sha256-…"; };
  aarch64-linux = { asset = "arm64"; hash = "sha256-…"; };
};
```

```bash
# ① 上游 SHA256SUMS（十六进制）转 SRI
curl -sL https://github.com/djyde/dalibre/releases/download/v<版本>/SHA256SUMS \
  | grep 'linux-\(amd64\|arm64\)\.tar\.gz'
nix hash convert --hash-algo sha256 --to sri <hex>
```

- 资产名规则是 `dalibre-<版本>-linux-<amd64|arm64>.tar.gz`。
- 升级只改 `version` + 两个哈希。tar.gz 内是平铺文件（无顶层目录），
  包内用 `sourceRoot = "."` 处理，换打包方式时留意。
- **不要**用应用内的「检查更新 / 安装更新」：它把新版本写回可执行文件所在目录，
  store 只读必然失败（与 magpie 同一个坑）。

### release 资产（tar.gz，`pulse`）

与 `dalibre` 同型（预编译 Go 单文件 + 平铺 tar.gz），差别是**上游不发 `SHA256SUMS`**，
哈希直接对资产取：

```bash
nix store prefetch-file --json \
  https://github.com/egoist/pulse-feedback/releases/download/v<版本>/pulse-<版本>-linux-amd64.tar.gz \
  | jq -r .hash
# arm64 同理，把 amd64 换成 arm64
```

- 资产名规则是 `pulse-<版本>-linux-<amd64|arm64>.tar.gz`；查最新版本读
  `https://github.com/egoist/pulse-feedback/releases/latest/download/update-linux-amd64.json`
  的 `version` 字段（也是应用内更新器读的那份清单）。
- 升级只改 `version` + 两个哈希。
- **patchelf 必须用 `patchelfUnstable`**（见 `docs/quirks.md` 的 Pulse 条目），
  别删 `nativeBuildInputs` 里那一行。
- **不要**用应用内的「检查更新」：mygo 更新器把新版本写回可执行文件所在目录，
  store 只读必然失败（与 magpie / dalibre 同一个坑）。

### release 资产（deb，`misterdownloadmanager`）

与 `flclash` 同型：上游发预编译 deb + `SHA256SUMS.txt`，目前只有 x86_64-linux：

```nix
version = "0.5.2";

sources = {
  x86_64-linux = { hash = "sha256-…"; };
};
```

```bash
# ① 上游 SHA256SUMS.txt（十六进制）转 SRI
curl -sL https://github.com/anefzaoui/misterdownloadmanager/releases/download/v<版本>/SHA256SUMS.txt \
  | grep 'linux-x86_64\.deb'
nix hash convert --hash-algo sha256 --to sri <hex>
```

- 资产名规则是 `MisterDownloadManager-<版本>-linux-x86_64.deb`。
- 升级只改 `version` + 哈希。
- **四个可执行文件必须留在 `$out/bin`**：GUI 用
  `current_exe().with_file_name("misterdownloadmanager-nmhost")` 找浏览器
  Native Messaging Host，挪到 libexec 会让扩展连不上。
- **不要**用应用内的「检查更新 / 登录时启动」：两者都把绝对 store 路径写回
  可执行文件/自启目录，升级被 GC 后失效（与 magpie / dalibre 同一个坑）。

### commit 钉法（`mactahoe-*` / `whitesur-kde`）

```nix
rev = "<新 commit>";
version = "<该 commit 的日期，YYYY-MM-DD 或 0-unstable-YYYY-MM-DD>";
```

```bash
nix flake prefetch --json github:<owner>/<repo>/<rev> | jq -r .hash
git log -1 --format=%ci <rev>   # 取日期填 version
```

- `mactahoe-gtk-theme` / `mactahoe-icon-theme` 有日期 tag：`rev` 填 **tag 指向的 commit**
  （`git ls-remote --tags --refs` 直接给出 rev），`version` 填该 tag 名（两者现在一致）。
  早期曾出现 `version = "2026-08-07"` 而 tag 叫 `2026-08-08` 的一天偏差，现在按 tag 名写即可。
- `mactahoe-kvantum` / `mactahoe-sddm-theme` 上游（MacTahoe-kde）没有 tag，跟 main HEAD；两者同源同 rev，升级一处即可。
- `whitesur-kde` 不是「追最新」的包：它只覆盖 nixpkgs 的 `whitesur-kde` 源码快照，补上
  nixpkgs 钉的 2024-11-18 里还没有的 `contents/logout`。故钉在 2024-12-12 的
  `5013507`（该提交只加注销界面）；`whitesur-plasma-splash` 与 `whitesur-sddm-theme`
  都继承它的 `version` / `src`，升级只需改这一处并重取哈希。

### 跟随 flake 输入（`windows-vm-media`）

不手工改版本：`version` 继承 nixpkgs 的 `virtio-win`，`oem/` 脚本按 `flake.lock` 的
`winapps` rev 抓取。升级 `winapps` 输入后，`oemFiles` 里四个哈希会失配并**显式构建失败**
（这是设计，不是回归）—— 按报错重取：

```bash
nix store prefetch-file --json \
  https://raw.githubusercontent.com/winapps-org/winapps/<新 rev>/oem/<文件名> | jq -r .hash
```

### 静态镜像（`pingfang-sc`）

仓库是 2019 年的 macOS 苹方 OTF 镜像，不跟版本、不打 tag，上游基本不会再动。
真要换 rev（比如要繁体 HK 或新字重）：改 `pkgs/pingfang-sc/default.nix` 的 `rev`，
用 `nix flake prefetch --json github:yunforge/Font-PingFang/<rev>` 取哈希，
再核对 `SC/PingFangSC_*.otf` 的 sha256 是否变了（变了才是真的换字体）。

## 坑

- **magpie 有两个产物**（`gui` 参数）：`magpie` 与 `magpie-cli` 同源同哈希，升版本改一处即可；
  桌面文件与自启由 HM 托管，见 `docs/quirks.md` 的「magpie 升级后 GUI 仍起来旧版本」。
- **主题升级要看 `docs/themes.md`**：2026-11-22 起 GTK / Qt / 图标 / SDDM 全部换成
  WhiteSur（GTK 用 nixpkgs 的 `whitesur-gtk-theme`，图标 `whitesur-icon-theme`，
  Plasma 用本仓库的 `whitesur-kde`）。niri 装饰色与 Noctalia 调色板仍是 MacTahoe 的
  具体色值（`customPalettes.mactahoe`，2026-09-10 版实测 `#242424` / `#dedede` /
  `#333333` / `#0088FF`），不随主题包升级变化；`mactahoe-*` 四个包的产物已无消费方，
  定义惰性保留，便于回退。
- **`mactahoe-gtk-theme` 的 `installPhase` 要给临时 `HOME`**：上游 2026-09-10 起新增
  `install_app`，会把 `gnome-theme-switcher` 装到 `$HOME/.local/`；构建沙箱的
  `HOME=/homeless-shelter` 不可写 → `cp` 失败、`set -Eeo pipefail` 直接 exit 1。
  包内 `export HOME=$(mktemp -d)` 把文件丢在临时目录（本机切换由 `theme-apply` 负责）。
- **上游脚本把 stderr 重定向到临时文件**：`libs/lib-core.sh` 里 `exec 2> $MACTAHOE_TMP_DIR/error_log.txt`，
  构建失败时 `nix log` 只看得到截断的 stdout。排查时把 `installPhase` 临时改成
  `HOME=/nix/store ./install.sh ...` 手工跑一遍，再看 `/tmp/MacTahoe.lock/error_log.txt`。
- **flclash 的 bundle 目录布局不能改**：上游 `lib/common/path.dart` 用
  `dirname(Platform.resolvedExecutable)` 拼 `FlClashCore` / `FlClashHelperService`，
  GUI 与 core 必须同目录，`lib/`、`data/` 相对该目录。包内整体放
  `$out/libexec/flclash/`，`$out/bin/FlClash` 是 exec 的 wrapper——软链会让
  `resolvedExecutable` 落到软链路径上，core 就找不到了。
- **flclash 的 `$ORIGIN/lib` 不能被 autoPatchelf 换掉**：FlClash 与 libflutter 都靠
  `RUNPATH=$ORIGIN/lib` 找引擎与插件 .so，nixpkgs 的 autoPatchelf 默认把 RUNPATH 换成
  绝对 store 路径。故包内设 `autoPatchelfFlags = [ "--preserve-origin" ]`（nixpkgs 自己的
  `pkgs/test/auto-patchelf-hook-preserve-origin` 就是这个用例）。
- **flclash 只剩「系统代理」模式**：TUN 模式依赖 `FlClashHelperService` 提权（上游 Linux
  包装给 setuid root），Nix store 不允许 setuid。仓库的客户机透明转发走 redsocks +
  mihomo，不依赖 TUN，不受影响。
- **flclash 与 clash-verge-rev 抢同一批端口**（7890/7897/1053），两者只能同时开一个。
  2026-10-28 已把系统里的 clash-verge-rev 换成 FlClash：两者都是 Clash 内核的 GUI，
  但 FlClash 沿用同一套端口（mixed-port 7897、dns listen 0.0.0.0:1053），
  `modules/nixos/networking/proxy*.nix` 不用改。
- **升级后必须跑 `nix flake check`**：它会逐一评估 `packages.*`，哈希失配与依赖 API 变更
  在这一步就暴露，不必等到主机 dry-build。

## 新增自维护包

1. `pkgs/<名字>/default.nix`，文件头写清「为什么自己打包 / 为什么这么钉 / 怎么升级」；
2. 在 `overlays/default.nix` 加一行 `prev.callPackage`，并在注释里写清用途与消费方；
3. 本文件清单表加一行；
4. `nix flake check` 会自动评估 `packages.<名字>`（按 `meta.platforms` 过滤）。
