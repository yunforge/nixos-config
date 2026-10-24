# 架构速查

面向 Agent 与人的仓库地图：仓库结构、模块层级、平台边界、角色组合、主机差异。
改配置前先看这里；某个子系统的细节见 `docs/README.md` 的索引。

## 仓库结构

```text
flake.nix / flake.lock      # 唯一入口：inputs + 各主机输出 + overlays/packages/checks + devShell/formatter
├─ lib/                     # 跨模块共享函数（wrapQtXWayland）与平台枚举（forAllSystems）
├─ hosts/<host>/            # 每台主机 = 声明文件 + nixos-generate-config 产物；只放该主机的差异
├─ modules/
│  ├─ nixos/                # NixOS 系统层
│  │  ├─ core/              # 真正通用的系统基础（引导 / Nix / 用户 / SSH / locale）
│  │  ├─ hardware/          # 硬件能力（蓝牙 / 音频 / 网络 / MCU / NVIDIA）
│  │  ├─ desktop/           # Linux 桌面能力（GDM / Niri / 输入法 / Distrobox / Steam）
│  │  ├─ networking/        # 代理（本机 / 客户机转发）
│  │  ├─ virtualization/    # QEMU/KVM 虚拟化
│  │  └─ profiles/          # 角色配置（workstation / server / wsl）
│  ├─ darwin/               # macOS 系统层：base / users / gui（Homebrew casks + 系统设置）
│  └─ home-manager/         # 用户层（跨平台共享）
│     ├─ common/            # 公共用户环境：shell / editors / tools（所有主机）
│     ├─ dev/               # 语言工具链（languages/）
│     ├─ gui/
│     │  ├─ apps/shared/    # 跨平台 GUI 应用配置（Ghostty / VSCode）
│     │  ├─ apps/linux/     # Linux 专属 GUI 应用
│     │  └─ desktop/linux/  # Linux 桌面会话（niri / themes / mimeapps / winapps）
│     ├─ platform/          # 平台专属适配（linux.nix / darwin.nix）
│     └─ profiles/          # 角色配置（workstation / server / wsl / macbook）
├─ overlays/ + pkgs/        # 自维护包的单一注入点与包本体
├─ docs/                    # 子系统深度说明，索引见 docs/README.md
└─ .github/workflows/       # flake-check（eval + dry-build + niri validate）、flakehub-publish
```

编辑之前：
1. 检查 `flake.nix`（主机如何套用角色）
2. 确认目标 `nixosConfiguration` / `darwinConfiguration`
3. 检查相关角色模块（`modules/*/profiles/`）与主机配置（`hosts/`）
4. 在添加新配置之前，先搜索现有的模块/选项。

## 模块分层

四层结构，**职责单一、复用优先**：

| 层 | 位置 | 职责 |
|----|------|------|
| 原子模块（Implementation） | `modules/*/<域>/<工具>.nix` | 实现一个工具或职责明确的功能（tmux、Neovim、Rust 工具链、Niri …） |
| 能力模块（Capability） | `modules/*/<域>/default.nix` | 聚合同类原子模块，用 `mkDefault` 给出域默认开关 |
| 角色配置（Profile） | `modules/*/profiles/<角色>.nix` | 决定某类设备需要哪些能力（workstation / server / wsl / macbook） |
| 设备配置（Host） | `hosts/<host>/` | 声明真实主机差异（硬件、显示器、驱动、特殊修复） |

系统平台层（`modules/nixos/`、`modules/darwin/`）承载 NixOS / nix-darwin 特有的系统集成。

### NixOS 系统层

- **core**：真正通用的系统基础——引导、Nix 设置、用户、SSH、locale 与字体、GC、
  自动升级、FHS 兼容（nix-ld）。所有 NixOS 主机（含服务器）共享，不含桌面/硬件能力。
  core **只**定义三个顶层域开关（`mySystem.hardware/desktop/virtualization.enable`）
  与 `mySystem.primaryUser`，其余选项都在各自功能模块里。
- **能力域**（hardware / desktop / networking / virtualization）：由各自
  `default.nix` 用 `mkDefault` 给出域内默认开关，主机只写例外（关单项用 `lib.mkForce`）。
- **角色**（`modules/nixos/profiles/`）：决定某类设备启用哪些系统能力，
  并承载角色级安全策略（见下方「角色组合」）。

### Home Manager 用户层

- **common**（`modules/home-manager/common/`）：跨平台公共配置——
  shell（Fish + direnv / eza / zoxide / fzf / bat / ripgrep / fd / jq …）、
  editors（Neovim）、tools（tmux / yazi / lazygit / btop / fastfetch / yt-dlp …）。
  所有主机无条件导入，Linux 专属工具由各叶子模块用
  `lib.optionals stdenv.hostPlatform.isLinux` 自行过滤。
- **dev**（`modules/home-manager/dev/languages/`）：语言工具链
  （Go / Node / Rust / Python / C++ / 其它 LSP）。与普通 CLI 分层：
  是否安装完整工具链由角色决定（`myHome.dev.enable`）。
- **gui**（`modules/home-manager/gui/`）：
  - `apps/shared/`：跨平台 GUI 应用**配置**（Ghostty / VSCode）。
    配置共享，安装方式按平台分开：Linux 走 HM 的 `programs.<name>` 装包，
    macOS 走 `modules/darwin/gui.nix` 的 Homebrew casks（HM 侧 `package = null`）。
  - `apps/linux/`：Linux 专属 GUI 应用（浏览器 / 通讯 / 媒体 / mpv /
    生产力 / Steam / 开发 / 嵌入式 / 工具 / Pot）。
  - `desktop/linux/`：Linux 桌面会话（Niri / Noctalia / 主题与亮暗切换 /
    MIME 关联 / WinApps）。输入法只在系统层接线（`modules/nixos/desktop`）。
- **platform**（`modules/home-manager/platform/`）：平台专属用户级适配
  （Linux 的 XDG 用户目录等）。
- **profiles**（`modules/home-manager/profiles/`）：角色的用户层组合。

## 角色组合

### NixOS 主机（系统层 + 用户层双角色）

| 设备 | 系统角色 | HM 角色 | 说明 |
|------|----------|---------|------|
| desktop | `nixos/profiles/workstation.nix` | `profiles/workstation.nix` | 完整工作站：硬件 + 桌面 + 虚拟化 + 代理 + GUI 应用 + 桌面会话 |
| laptop | `nixos/profiles/workstation.nix` | `profiles/workstation.nix` | 与 desktop 同一角色，仅硬件/显示器/电源差异 |
| server | `nixos/profiles/server.nix` | `profiles/server.nix` | 最小系统基础 + 服务器安全策略（SSH 密钥认证）；无桌面、无 GUI、无音视频 |
| wsl | `nixos/profiles/wsl.nix` | `profiles/wsl.nix` | NixOS-WSL 集成 + 代理探测；无桌面、无 GUI |

server 角色的明确策略：
- SSH 关闭密码认证（`PasswordAuthentication = false`，只允许密钥），
  `PermitRootLogin = prohibit-password`；防火墙只放行 22（core）。
- 不启用桌面 / 硬件 / 虚拟化；代理默认关闭，需要时在主机文件里开。
- 自动升级与回滚沿用 core 的全局策略（autoUpgrade 走 flake、`allowReboot = false`
  靠 `configurationLimit = 10` 的代际回滚，GC 7 天）。

### MacBook（darwin）

`hosts/macbook` → `modules/darwin`（系统层）+ `modules/home-manager/profiles/macbook.nix`。
HM 侧导入：common + dev + `gui/apps/shared`（跨平台 GUI 应用配置）+ darwin 平台适配。
**不导入** `gui/apps/linux` 与 `gui/desktop/linux`。

## 选项约定

- 选项**就近定义在实现该功能的模块里**，不集中到 core。
- 每个域的**聚合模块**（如 `hardware/default.nix`、`desktop/default.nix`）用 `lib.mkDefault`
  给出该域的默认开关组合，主机文件因此只写**例外**（关单项用 `lib.mkForce`）。
- 主机数据（如 `mySystem.desktop.monitors`）留在 `hosts/`；共享模块只做生成器与消费方。
- 选项根按平台层分：系统层（NixOS / nix-darwin）用 `mySystem.*`，用户层（HM）用
  `myHome.*`。两者都不含用户名——账户名只由 `mySystem.primaryUser` /
  `system.primaryUser` 声明，改用户名不需要动选项树。
- HM 层门控：`myHome.cli.enable`（common）、`myHome.dev.enable`（dev）、
  `myHome.gui.enable`（GUI 应用）、`myHome.desktop.enable`（Linux 桌面会话）。
  这四个开关由角色 profile 用 `mkDefault` 给出，主机可用 `mkForce` 覆盖。

**选项清单不在文档里维护**：`rg 'mkEnableOption|mkOption' modules/` 是唯一权威。
手抄的表一定会漂，所以这里没有它。

## 主机差异

| Host | System | 相对其它主机的差异 |
|------|--------|-------------------|
| desktop | x86_64-linux | 多 `desktop.steam.enable`；i2c（DDC 调光）+ EDID 冷启动自愈补丁；RTX 3060Ti，4K@150Hz |
| laptop | x86_64-linux | 内屏 1080p；额外 libvirt TPM2 凭证解密修复；MX150（legacy 驱动，PRIME offload），btrfs，TLP |
| server | x86_64-linux | 新主机（无桌面）：`hosts/server/default.nix` 只含主机名与占位文件系统；`hardware-configuration.nix` 需在目标机器生成后导入 |
| wsl | x86_64-linux | CLI-only，`boot.isContainer`，额外 WSL2 代理地址探测（`hosts/wsl/proxy.nix`） |
| macbook | aarch64-darwin | nix-darwin，Homebrew casks |

desktop 与 laptop 共享 **workstation 角色**：桌面能力（niri / distrobox /
virtualization / proxy）由角色与 `desktop.enable` 的聚合默认值给出，
主机文件里只留硬件数据与真正的差异。

## 跨平台共享边界

**共享配置、分开安装**：

| 配置 | 共享范围 | 安装方式 |
|------|----------|----------|
| Fish / tmux / Neovim / bat / ripgrep … | 所有主机 | HM 的 `programs.<name>`（各模块自行过滤 Linux 专属工具） |
| 语言工具链 | workstation / server / wsl / macbook | HM `home.packages`（Linux 专属工具按平台过滤） |
| Ghostty / VSCode 用户配置 | Linux 工作站 + MacBook | Linux：HM 装包；macOS：Homebrew cask（HM 侧 `package = null`） |
| Linux GUI 应用 | 仅 Linux 工作站 | HM `home.packages` |
| Niri / Noctalia / 主题 / 输入法 | 仅 Linux 工作站 | HM 配置 + NixOS 系统模块 |
| macOS 系统设置 / Homebrew | 仅 MacBook | `modules/darwin` |

**禁止**：在公共模块中散布设备名称判断（`if host == "desktop"`）；
为某台设备复制整份 CLI/TUI 配置。

## Overlay 与自定义包

`overlays/default.nix` 是 `pkgs/` 自维护包的单一注入点，三处消费同一份清单：

- NixOS 系统级：`modules/nixos/core` 的 `nixpkgs.overlays`
- macOS 系统级：`modules/darwin/base` 的 `nixpkgs.overlays`
- flake 输出：`overlays.default` 与 `packages.*`（`nix flake check` 会逐一评估，
  nixpkgs 滚动带来的包级回归在 CI 即暴露）

Home Manager 走 `useGlobalPkgs = true` 复用系统级实例，不单独注入 overlay。

自维护包的版本、钉法与升级步骤见 `docs/packages.md`。

## Home Manager 接线

`flake.nix` 的 `mkHomeManager` 是 NixOS 与 darwin **共用的唯一一份**接线：

- `useGlobalPkgs = true`，用户名从宿主的 primaryUser 选项派生——NixOS 取
  `mySystem.primaryUser`，darwin 取 nix-darwin 的 `system.primaryUser`
  （由 `mkHomeManager` 的 `primaryUser` 参数指定）。
- `profile` 参数指定角色模块（`modules/home-manager/profiles/<角色>.nix`）：
  角色决定导入哪些能力层，主机不再自己拼 extraModules。
  原先的 `extraModules = [ ./modules/home-manager/gui ]` 已由 profile 取代。
