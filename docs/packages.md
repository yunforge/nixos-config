# 自维护包（nixpkgs 未收录）

`pkgs/` 下是**仓库自己打包**的应用与主题：nixpkgs 没有，或 nixpkgs 的版本不满足需求。
它们的版本号钉死在仓库里，`nix flake update` **不会**带动它们 —— 只有这里列出的包需要手工升级。

单一注入点是 `overlays/default.nix`（三处消费：NixOS `nixpkgs.overlays`、darwin
`nixpkgs.overlays`、flake 输出的 `packages.*`）。**加包 / 改包先看这里，别在模块里另起一套。**

## 清单

版本核对于 2026-10-20（当日全部升到上游最新）。

| 属性名 | 上游 | 钉法 | 当前钉住 | 上游最新 | 状态 |
|--------|------|------|----------|----------|------|
| `babry` | [kregonia/babry](https://github.com/kregonia/babry) | tag | `v0.1.4` | `v0.1.4` | 最新 |
| `magpie` / `magpie-cli` | [yetone/magpie](https://github.com/yetone/magpie) | tag | `v0.1.1296` | `v0.1.1296` | 最新 |
| `mcpp-m` | [mcpp-community/mcpp](https://github.com/mcpp-community/mcpp) | release 资产 | `2026.10.19.1` | `2026.10.19.1` | 最新 |
| `liquidbird` | [StatIndet/liquidbird](https://github.com/StatIndet/liquidbird) | commit（main） | `0f8148d` | 同一 commit | 最新 |
| `mactahoe-gtk-theme` | [vinceliuice/MacTahoe-gtk-theme](https://github.com/vinceliuice/MacTahoe-gtk-theme) | commit（tag 指向） | `0aa2a2b`（tag `2026-09-10`） | 同一 commit | 最新 |
| `mactahoe-icon-theme` | [vinceliuice/MacTahoe-icon-theme](https://github.com/vinceliuice/MacTahoe-icon-theme) | commit（tag 指向） | `839848b`（tag `2026-09-10`） | 同一 commit | 最新 |
| `mactahoe-kvantum` | [vinceliuice/MacTahoe-kde](https://github.com/vinceliuice/MacTahoe-kde) | commit（main，无 tag） | `cbf6a1f` | 同一 commit | 最新 |
| `windows-vm-media` | virtio-win（nixpkgs）+ WinApps `oem/` | 跟随 flake 输入 | — | — | 不手工升级 |

各包的**为什么这么打包**写在 `pkgs/<包名>/default.nix` 文件头，这里不重复。

消费方（改包时确认影响面）：

| 包 | 装在哪 |
|----|--------|
| `babry` | `modules/home-manager/gui/apps/linux/utilities.nix`（`Mod+P` / `Mod+Ctrl+P`，见 `docs/niri.md`） |
| `magpie` | 同上（desktop/laptop 桌面版）；`magpie-cli` 在 `hosts/wsl/default.nix` |
| `mcpp-m` | `modules/home-manager/dev/languages/cpp.nix`（所有 Linux 主机 + macbook） |
| `liquidbird` | `modules/home-manager/gui/apps/linux/productivity.nix`（Thunderbird 主题） |
| `mactahoe-*` | `gui/desktop/linux/themes/default.nix`、`themes/variants.nix`、`modules/nixos/desktop/gdm.nix` |
| `windows-vm-media` | `modules/nixos/virtualization`（`mySystem.virtualization`） |

不在本清单里的东西：nixpkgs 里的一切（跟着 `nix flake update` 走）、flake inputs
（nixpkgs / nur / winapps / home-manager / noctalia / msime / zen-browser）。
另有一处**不是包但同样钉住哈希**的取物：`gui/apps/linux/pot.nix` 的 `pot-icon`
（取 `pot-desktop` master 分支的 `icon.svg`，上游改文件即构建失败，需重取哈希）。

## 「更新系统」时的固定动作

用户说**「更新系统」**时，除了刷 flake 输入，还要按本清单逐个查上游并升级落后的包：

```bash
# 1. 刷新 flake 输入（nixpkgs / HM / noctalia / winapps …）
nix flake update

# 2. 查各包上游（命令见下面「查上游最新版本」一节），有新版就按钉法升级

# 3. 验证
nix fmt
nix flake check
nix build --dry-run .#babry .#magpie .#magpie-cli .#mcpp-m .#liquidbird \
  .#mactahoe-gtk-theme .#mactahoe-icon-theme .#mactahoe-kvantum .#windows-vm-media
nix build --dry-run .#nixosConfigurations.desktop.config.system.build.toplevel
```

升级提交单独成 commit（`feat(<scope>): 升级到 <版本>`，见 `git log --oneline` 惯例），
不要和 flake 输入刷新混在一起 —— 出问题时能单独回退。

## 查上游最新版本

```bash
# 打 tag 的仓库（babry / magpie / MacTahoe-*）
git ls-remote --tags --refs https://github.com/<owner>/<repo> \
  | sed 's#.*refs/tags/##' | sort -V | tail -3

# 走 GitHub Release 的（mcpp）：看 latest 跳转到哪个 tag
curl -sI https://github.com/<owner>/<repo>/releases/latest | grep -i '^location'

# 跟 main 走的（liquidbird / MacTahoe-kde）：HEAD 即最新
git ls-remote https://github.com/<owner>/<repo> HEAD
```

## 按钉法升级

哈希统一用 `nix flake prefetch` 取（与 `fetchFromGitHub` 的 `stripRoot = true` 同源，
结果与包里钉的哈希逐字一致，不必再靠 `lib.fakeHash` 试错）：

```bash
nix flake prefetch --json github:<owner>/<repo>/<tag 或 rev> | jq -r .hash
```

### tag 钉法（`babry`、`magpie`）

```nix
version = "0.1.1296";   # ① 改版本
```

```bash
# ② src 哈希
nix flake prefetch --json github:yetone/magpie/v0.1.1296 | jq -r .hash
```

- `cargoHash`（babry）/ `vendorHash`（magpie）只在 `Cargo.lock` / `go.mod`+`go.sum`
  变化时需要重算，同样填 `lib.fakeHash` 跑一次构建，取报错里的 `got:`。
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

### commit 钉法（`liquidbird`、`mactahoe-*`）

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
- `mactahoe-kvantum` 上游没有 tag，跟 main HEAD。
- `liquidbird` 上游尚未为 Linux 侧打 tag（`v0.1.0` 只有 macOS），继续跟 main commit。

### 跟随 flake 输入（`windows-vm-media`）

不手工改版本：`version` 继承 nixpkgs 的 `virtio-win`，`oem/` 脚本按 `flake.lock` 的
`winapps` rev 抓取。升级 `winapps` 输入后，`oemFiles` 里四个哈希会失配并**显式构建失败**
（这是设计，不是回归）—— 按报错重取：

```bash
nix store prefetch-file --json \
  https://raw.githubusercontent.com/winapps-org/winapps/<新 rev>/oem/<文件名> | jq -r .hash
```

## 坑

- **babry 的 `save_dir` 要 0.1.4 起才生效**（0.1.1 不读 `config.toml`）。升级时别降版本，
  详见 `docs/quirks.md`。
- **babry `doCheck = false`**：上游测试要系统字体、且像素断言本身不稳定；上游 CI 也只
  `cargo build`。修好后恢复 check，见 `pkgs/babry/default.nix` 注释。
- **magpie 有两个产物**（`gui` 参数）：`magpie` 与 `magpie-cli` 同源同哈希，升版本改一处即可；
  桌面文件与自启由 HM 托管，见 `docs/quirks.md` 的「magpie 升级后 GUI 仍起来旧版本」。
- **主题升级要看 `docs/themes.md`**：GTK/Qt/图标三套必须同源，niri 装饰色与 Noctalia
  调色板都取自 MacTahoe 的具体色值，换主题版本可能让 `customPalettes.mactahoe` 的取值失配。
  2026-09-10 版实测配色未变（`#242424` / `#dedede` / `#333333` / `#0088FF`），
  图标变体目录仍是 `MacTahoe-dark` / `MacTahoe-light`（与 `variants.nix` 引用一致）。
- **`mactahoe-gtk-theme` 的 `installPhase` 要给临时 `HOME`**：上游 2026-09-10 起新增
  `install_app`，会把 `gnome-theme-switcher` 装到 `$HOME/.local/`；构建沙箱的
  `HOME=/homeless-shelter` 不可写 → `cp` 失败、`set -Eeo pipefail` 直接 exit 1。
  包内 `export HOME=$(mktemp -d)` 把文件丢在临时目录（本机切换由 `theme-apply` 负责）。
- **上游脚本把 stderr 重定向到临时文件**：`libs/lib-core.sh` 里 `exec 2> $MACTAHOE_TMP_DIR/error_log.txt`，
  构建失败时 `nix log` 只看得到截断的 stdout。排查时把 `installPhase` 临时改成
  `HOME=/nix/store ./install.sh ...` 手工跑一遍，再看 `/tmp/MacTahoe.lock/error_log.txt`。
- **升级后必须跑 `nix flake check`**：它会逐一评估 `packages.*`，哈希失配与依赖 API 变更
  在这一步就暴露，不必等到主机 dry-build。

## 新增自维护包

1. `pkgs/<名字>/default.nix`，文件头写清「为什么自己打包 / 为什么这么钉 / 怎么升级」；
2. 在 `overlays/default.nix` 加一行 `prev.callPackage`，并在注释里写清用途与消费方；
3. 本文件清单表加一行；
4. `nix flake check` 会自动评估 `packages.<名字>`（按 `meta.platforms` 过滤）。
