# 开发环境

## 全局环境

**全局环境**：由 home-manager 管理的用户环境，**按角色组合**而非按设备复制：

| 层 | 位置 | 内容 |
|----|------|------|
| common | `modules/home-manager/common/` | 所有主机共享：shell / editors / 命令行与 AI 工具 |
| dev | `modules/home-manager/dev/languages/` | 语言工具链（Go / Node / Rust / Python / C++ / 其它 LSP） |
| gui/apps/shared | `modules/home-manager/gui/apps/shared/` | 跨平台 GUI 应用配置（Ghostty / VSCode） |
| platform | `modules/home-manager/platform/` | 平台专属用户级适配（Linux 的 XDG 用户目录） |

各设备的用户环境由角色 profile 组合（`modules/home-manager/profiles/`）：

| 设备 | common | dev | gui apps | 桌面会话 |
|------|--------|-----|----------|----------|
| desktop / laptop | ✓ | ✓ | shared + linux | ✓（Niri / Noctalia / fcitx5 …） |
| server | ✓ | ✓ | ✗ | ✗ |
| wsl | ✓ | ✓ | ✗ | ✗（无 Linux 桌面会话） |
| macbook | ✓ | ✓ | shared（macOS 用 Homebrew 安装） | ✗（macOS 自己的桌面） |

common 与 dev 里的 Linux 专属工具由各叶子模块用 `lib.optionals stdenv.hostPlatform.isLinux`
自行过滤，公共模块里**没有设备名称判断**。

- Shell：Fish + 常用 CLI 工具（eza / zoxide / bat / fzf / ripgrep / fd / jq / yq）
- 编辑器：Neovim（`nvim`）+ VSCode（GUI）+ CLion
- AI 编程：Claude Code（`cc` 别名）、pi-coding-agent、CodeX
- GitHub CLI：`gh`（`~/.config/gh/config.yml` 由 `programs.gh.settings` 生成，`gh config set` 的改动会被下次激活覆盖；`hosts.yml` 与登录状态不接管，token 在 keyring）

### 语言工具链

| 语言 | 工具 | LSP / 辅助 |
| --- | --- | --- |
| Go | `go` | gopls |
| Node.js | `fnm`、`yarn`、`pnpm` | typescript-language-server、prettier、eslint |
| Rust | `rustc`、`cargo` | rust-analyzer、rustfmt、clippy、cargo-watch/audit/outdated/nextest、taplo、cargo-cross |
| Python | `python3`（**跟随 nixpkgs 默认，不钉版本**，升级 flake 时整体平移）、`uv` | python-lsp-server、ruff、black、isort、mypy、pytest、pylint、bandit、mkdocs |
| C/C++ | `clang`、`cmake`、`ninja`、`vcpkg` | clangd（clang-tools）、cppcheck、lldb、valgrind、perf-tools、strace |
| 其他 | bash / lua / nix / markdown / yaml / kdl | bash-language-server、lua-language-server、nil、marksman、ltex-ls-plus、yaml-language-server、kdlfmt |

> 注意：Python 使用 `uv` 作为首选包管理器（替代 pip/poetry）。

## 项目环境

**项目环境**：每个项目通过 `flake.nix` 定义开发定制环境。

项目环境的优先级是最高的，其中的依赖会覆盖全局环境中的同名依赖。

### nix shell

```bash
$ hello
fish: 未知的命令：hello

# 1. 进入一个包含 hello 的临时环境
$ nix shell nixpkgs#hello
$ hello
世界你好！

# 2. 退出环境
$ exit

# 3. 直接运行 cowsay，用完即走
nix run nixpkgs#cowsay -- "Hello, Nix!"
```

- `nix shell`：用于进入到一个含有指定 Nix 包的环境并为它打开一个交互式 shell。
- `nix run`：用于直接运行一个 Nix 包，而不需要进入环境。

## 容器的开发环境（Distrobox）

desktop / laptop 已启用 Distrobox + Podman，可快速进入其它发行版环境：

```bash
arch     # distrobox enter arch
ubuntu   # distrobox enter ubuntu
```

### 容器 home 与宿主隔离

distrobox 默认拿宿主 `$HOME` 当容器 home，两个方向都会出问题：

- 宿主 HM 生成的 `~/.config/fish` 被容器里的 fish 读到，里面引用了容器没装的
  `eza` / `zoxide` / `fnm`，进容器就报错；
- 容器里 `pip install --user` / `cargo install` 写进 `~/.local/bin`、`~/.cargo/bin`，
  宿主 PATH 里又有这些目录，容器装的二进制“跑”到了宿主上，绕过 NixOS 包管理。

`mengw.cli.tools.distrobox`（`modules/home-manager/common/tools/distrobox.nix`）因此写
`~/.config/distrobox/distrobox.conf`，设 `container_home_prefix = ~/.distrobox`：
新容器的 `HOME` 与 `XDG_*` 全部落在 `~/.distrobox/<name>`，宿主的 fish 配置和宿主
PATH 都不再被卷入。容器里 `distrobox` 可能有自己的 fish（arch/ubuntu 里装了），
读的是容器 home 里 `/etc/skel` 复制出来的默认配置。

该键只在 `distrobox create` 时写进容器配置，改完必须重建容器（容器里手动装的包会丢，
先记下来）：

```bash
podman exec arch pacman -Qqe                 # 记下 arch 里手动装的包
podman exec ubuntu bash -lc 'apt-mark showmanual'
distrobox rm --force arch ubuntu
distrobox create --name arch --image docker.io/library/archlinux:latest
distrobox create --name ubuntu --image docker.io/library/ubuntu:latest
distrobox-export --app <app>                 # 之前导出到宿主菜单的重新导出
```

注意隔离的是“默认写入位置”，不是权限边界：宿主 `$HOME` 仍以同一 UID 挂载在容器里
（`/home/mengw`，进程可用 `$DISTROBOX_HOST_HOME` 拿到），`~/Projects` 照旧能访问。
真要互不干扰，就别在容器里用 `--user` / `-g` 装东西。
