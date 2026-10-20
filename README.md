# nixos-config

我的个人 NixOS 配置。全部状态由 Nix Flakes + Home Manager 声明式管理：系统、用户环境、
桌面会话与应用都写在同一个仓库里，`git` 历史即回滚点。

- 声明式：不用命令式脚本“修好现场”再反向抄回来，改的是仓库里的期望状态。
- 可复现：`flake.lock` 钉死所有输入，任何一台机器都能重建出同一套环境。
- 模块化：按「原子模块 → 能力模块 → 角色 → 主机」分层，五类设备靠角色组合复用配置。
- 可回滚：每次部署生成新代际，旧代际留在 systemd-boot 启动项里。

## 主机

| 主机 | 系统 | 角色 | 说明 |
|------|------|------|------|
| `desktop` | x86_64-linux | workstation | 台式机，Niri 桌面，RTX 3060Ti + 4K@150Hz，开 Steam |
| `laptop` | x86_64-linux | workstation | 笔记本，同一套桌面，MX150 / PRIME offload、TLP |
| `server` | x86_64-linux | server | 无桌面无 GUI，SSH 只允许密钥认证 |
| `wsl` | x86_64-linux | wsl | WSL2，CLI-only，带代理地址探测 |
| `macbook` | aarch64-darwin | macbook | nix-darwin + Homebrew cask，与 Linux 侧共享用户配置 |

各主机到底组合了哪些能力层见 [`docs/architecture.md`](docs/architecture.md) 的「角色组合」。

## 仓库结构

```text
flake.nix / flake.lock   # 唯一入口：inputs、各主机输出、overlays、packages、checks、formatter
├─ hosts/<host>/         # 每台主机只写真实差异（硬件、显示器、驱动、特殊修复）
├─ modules/
│  ├─ nixos/             # 系统层：core / hardware / desktop / networking / virtualization / profiles
│  ├─ darwin/            # macOS 系统层：base / users / gui
│  └─ home-manager/      # 用户层：common / dev / gui / platform / profiles
├─ overlays/ + pkgs/     # nixpkgs 未收录的自维护包（唯一注入点 + 包本体）
├─ assets/               # 壁纸、fastfetch 配置等产品资产
├─ tests/                # 需要真机验证的脚本（如 tmux 会话持久化）
└─ docs/                 # 子系统深度说明，索引见 docs/README.md
```

分层约定、选项归属与平台边界不在本文件重复，见 [`docs/architecture.md`](docs/architecture.md)。
改动前先查 [`docs/README.md`](docs/README.md) 的索引，找到对应那篇。

## 部署新配置

```bash
# NixOS 笔记本
sudo nixos-rebuild switch --flake ~/Projects/nixos-config#laptop

# NixOS 主机
sudo nixos-rebuild switch --flake ~/Projects/nixos-config#desktop

# NixOS 服务器（首次部署前需在目标机器生成 hardware-configuration.nix）
sudo nixos-rebuild switch --flake ~/Projects/nixos-config#server

# WSL
sudo nixos-rebuild switch --flake ~/Projects/nixos-config#wsl

# macOS
darwin-rebuild switch --flake ~/Projects/nixos-config#macbook
```
此命令会根据当前配置文件生成一个新的系统环境，并将新的系统环境设为默认环境。

上一个系统环境也会保留，并加入 systemd-boot 启动项（最多保留 10 个，见 `boot.loader.systemd-boot.configurationLimit`）。

> Fish 里已封装别名：`updatedp` / `updatedplog` / `updatelp` / `updatelplog` / `updatewsl`
> （带 `log` 的是加 `--show-trace --print-build-logs --verbose` 的排错版）。

## 常用命令

```bash
# 格式化（nixfmt，裸调用即递归格式化全树）
nix fmt

# 校验：评估 flake 全部输出，并对每台开了 niri 的主机跑 niri validate
nix flake check

# 进入开发环境（git + treefmt/nixfmt）
nix develop

# 更新 flake.lock
nix flake update

# 删除所有当前系统未使用的包
sudo nix-collect-garbage --delete-old

# 存储优化
nix store optimise
```

> **「更新系统」= 刷 flake 输入 + 升自维护包。** `pkgs/` 里的包（babry、mactahoe、
  magpie、windows-vm-media 等）版本钉在仓库内，`nix flake update` 带不动它们。
> 清单与按包升级步骤见 [`docs/packages.md`](docs/packages.md)。

系统已配置每周自动 GC（`--delete-older-than 7d`）与每日自动升级
（`system.autoUpgrade`：只构建不重启，升级后把 `flake.lock` 提交回仓库保持工作区干净）。
装机后 Noctalia 还有几步一次性设置（壁纸、调色板、bar 布局），见
[`docs/manager.md`](docs/manager.md)。

## 我的配置

- Shell：[Fish](https://github.com/fish-shell/fish-shell)
- 终端：[Ghostty](https://ghostty.org/)、[Tern](https://stencil.so/tern)（手动装到 `~/Apps/Tern`）
- 终端复用：[tmux](https://github.com/tmux/tmux)
- 终端文件管理：[Yazi](https://github.com/sxyazi/yazi)（`y`）
- 编辑器：[Neovim](https://github.com/neovim/neovim)、[VSCode](https://code.visualstudio.com/)、
  [Zed](https://zed.dev/)、[CLion](https://www.jetbrains.com/clion/)
- AI 编程：Claude Code、CodeX、pi-coding-agent
- 输入法：水杉输入法（[MSIME](https://msime.app/)，Fcitx5 插件）
- 窗口管理器：[Niri](https://github.com/YaLTeR/niri)（Wayland 平铺合成器）
- 桌面外壳：[Noctalia](https://github.com/noctalia-dev/noctalia-shell)（启动器 / 控制中心 / 壁纸 / 锁屏）
- 浏览器：[Zen Browser](https://zen-browser.app/)（默认）、[Brave](https://brave.com/)
- 主题：壳层 MacTahoe（GTK / Qt / 图标，单一强调色 `#0088FF`）+ 工作区 Catppuccin
  （终端 / 编辑器 / shell / 文件管理器，Frappe / Latte 跟随亮暗）
- 字体：Maple Mono NF CN（代码）、HarmonyOS Sans SC（界面）、LXGW WenKai（中文衬线）

完整应用清单见 [`docs/softwares.md`](docs/softwares.md)，主题取舍见
[`docs/themes.md`](docs/themes.md)。

## 文档

| 想了解 | 看 |
|--------|----|
| 仓库结构、模块分层、选项约定、主机差异 | [`docs/architecture.md`](docs/architecture.md) |
| 平台坑位与 workaround（含移除条件） | [`docs/quirks.md`](docs/quirks.md) |
| Niri 快捷键与窗口规则 | [`docs/niri.md`](docs/niri.md) |
| 主题、亮暗切换、字体 | [`docs/themes.md`](docs/themes.md) |
| 输入法 | [`docs/input.md`](docs/input.md) |
| 开发工具链与 Distrobox | [`docs/environment.md`](docs/environment.md) |
| tmux 会话持久化 | [`docs/tmux.md`](docs/tmux.md) |
| WinApps / Windows 虚拟机 | [`docs/winapps.md`](docs/winapps.md) |
| 自维护包与升级 | [`docs/packages.md`](docs/packages.md) |
| 部署、升级、垃圾回收 | [`docs/manager.md`](docs/manager.md) |

全部文档索引见 [`docs/README.md`](docs/README.md)。

## 资源

- [查找包](https://search.nixos.org/packages)
- [查找设置](https://search.nixos.org/options)
- [更快的搜索](https://nixsearch.thekoppe.com/)
- [NixOS 中文](https://nixos-cn.org/manual/)
- [NixOS & Flakes Book](https://nixos-and-flakes.thiscute.world/zh/introduction/)
- [NixOS 中文论坛](https://discourse.nixos.org/c/learn/chinese/55)
- [Awesome-Nix](https://github.com/nix-community/awesome-nix)
