# AGENTS.md

## 项目概述

此仓库包含我的 NixOS 系统配置。

配置是声明式的，并使用 Nix Flakes 进行管理。

主要目标是保持系统配置：

- 声明式
- 可复现
- 模块化
- 易于理解
- 易于回滚

不要把这个仓库当作一堆 shell 脚本。更倾向于通过 NixOS/Home Manager 配置来表达系统状态。

## 深入文档在哪

本文件只放总规则（命令边界、验证、风格、提交）。仓库结构、选项映射、角色组合、主机清单与平台适配坑位都不在这里：

- `docs/architecture.md` — 仓库地图：结构、模块分层（原子模块 → 能力模块 → 角色 → 主机）、
  选项约定（就近 `mkEnableOption` / 聚合 `mkDefault` / 主机只写例外）、角色组合、主机差异、
  跨平台共享边界、overlay 与 HM 接线。**改任何模块结构前先读这篇。**
- `docs/quirks.md` — 平台适配的坑与 workaround（改对应模块前必读）
- `docs/packages.md` — `pkgs/` 自维护包的版本清单、按钉法的升级步骤；
  用户说「**更新系统**」时按这篇逐个把自维护包升到最新
- `docs/README.md` — 全部文档索引；改某个子系统前先读对应那篇

## 架构入口（改配置前必须知道的分层）

配置按「职责」而非「设备」组织，五类设备（desktop / laptop / server / wsl / macbook）
靠**角色 profile** 组合公共能力，主机文件只写真实差异：

- 系统层角色：`modules/nixos/profiles/`（workstation / server / wsl）
- 用户层角色：`modules/home-manager/profiles/`（workstation / server / wsl / macbook）
- 公共能力：`modules/home-manager/common/`（shell / editors / tools，所有主机共享）、
  `modules/home-manager/dev/languages/`（语言工具链）、
  `modules/home-manager/gui/apps/shared/`（跨平台 GUI 应用配置）
- 平台边界：GUI 应用「配置共享、安装方式分开」（Linux 走 HM 装包，macOS 走 Homebrew cask，
  HM 侧 `package = null`）；`gui/apps/linux/` 与 `gui/desktop/linux/` 只给 Linux 工作站导入。
- **禁止**在公共模块里散布设备名称判断；新增设备先看能不能靠新角色 profile 组合，不要复制配置。

详细约定与各主机的组合方式见 `docs/architecture.md`。

## AI 工作流系统

### 快速入门路径（按序执行，覆盖大多数任务）

1. **读本文** → 知道命令边界、验证、提交纪律。
2. **读 `docs/architecture.md`** → 仓库地图：结构、模块分层、选项约定（就近 `mkEnableOption` /
   聚合 `mkDefault` / 主机只写例外）、角色组合、主机差异、overlay 与 HM 接线。
3. **改某个子系统** → 查 `docs/README.md` 索引表，先读对应那篇（如改 niri → `docs/niri.md`）。
4. **遇到构建失败 / 注释掉的包 / 平台 hack** → 查 `docs/quirks.md`（是什么+根因+移除条件）。
5. **动手前**：用下面的命令找现有选项与惯例；无先例的改动先与用户确认。

### 「更新系统」的固定动作

用户说「**更新系统**」时，除了刷 flake 输入，还要把 `pkgs/` 里的自维护包升到最新
（它们的版本钉在仓库里，`nix flake update` 带不动）：

1. `nix flake update` 刷新 nixpkgs / HM / noctalia / winapps 等输入；
2. 打开 `docs/packages.md`，按清单逐个查上游最新版本，升级落后的包（钉法与取哈希命令都在那篇）；
3. 验证：`nix fmt` → `nix flake check` → `nix build --dry-run .#<每个自维护包>` →
   受影响主机的 toplevel dry-run；
4. 自维护包升级单独提交（`feat(<scope>): 升级到 <版本>`），不与 flake 输入刷新混在一起。

### 选项/模块清单查询（唯一权威，不在文档维护清单）

```bash
rg 'mkEnableOption|mkOption' modules/    # 每个选项的定义位置
rg 'mySystem\.' hosts/                   # 主机差异用法
rg 'mkDefault|mkForce' modules/ hosts/   # 默认值聚合与覆盖点
```

### 验证命令（改动后按风险递进，选合适深度）

```bash
nix fmt <改动的 .nix 文件>   # 必做（或全树 nix fmt）
nix flake check              # 必做（含 niri validate checks）
nix build --dry-run .#nixosConfigurations.<host>.config.system.build.toplevel
                             # 改对应主机时做；要真实产物就去掉 --dry-run
./tests/tmux-persistence.sh  # 改 tmux 时做（rebuild switch 后）
```

主机名单（`flake.nix` 枚举）：`desktop` / `laptop` / `server` / `wsl`（NixOS）、`macbook`（darwin）。
各主机的角色组合见 `docs/architecture.md` 的「角色组合」。

### 构建失败 / 上游回归处置

1. 先查 `docs/quirks.md` —— 已知坑位多数已记录（含根因与移除条件）。
2. 新发现的上游回归 → 注释掉包，并在 `docs/quirks.md` 补一行；上游修复后恢复包并删除对应记录。

### 记录纪律（改变仓库状态时的最低要求）

- 提交信息：`<type>(<scope>): 中文描述`，type 取 feat/fix/chore/style/revert，
  scope 是子系统（gui/cli/nvim/boot/desktop/magpie 等）—— `git log --oneline` 可见惯例。
- 涉及平台坑位/workaround 的改动 → 同一提交或紧随其后在 `docs/quirks.md` 补一行
  （是什么+根因+移除条件，≤3 行）。
- 新增/改名文件 → 同步 `docs/README.md` 索引表（如适用）。

## 通用规则

### 优先使用现有配置

在添加新选项或模块之前：
- 在仓库中搜索现有的实现；
- 尽可能复用现有模块；
- 避免重复配置；
- 遵循现有的组织结构和命名约定。

除非能带来明显好处，否则不要引入新的抽象。

### 保持配置声明式

优先使用 NixOS/Home Manager 选项，而不是命令式命令。

例如，更倾向于：

```nix
services.openssh.enable = true;
```

超过：

```nix
systemd.services.foo.script = '' 
  systemctl ... 
'';
```

除非有特定原因，否则不要使用命令式命令来绕过配置问题。

### 尽量减少更改

进行满足请求所需的最小改动。

不做：
- 重新格式化无关文件；
- 不必要地重组仓库；
- 未经要求就升级依赖；
- 修改无关服务；
- 在不解释原因的情况下改变现有行为。

## Nix Flakes

除非明确要求或必须更改依赖项，否则不得修改 `flake.lock`。

不要仅仅为了验证而运行更新 flake 输入的命令。

例如，避免：

```bash
nix flake update
```

除非用户明确请求输入更新。

## 格式化

使用仓库配置的格式化工具对更改的 Nix 文件进行格式化。

偏好：

```bash
nix fmt
```

如果 flake 提供了格式化程序。

不要手动重新格式化无关文件。

## 验证

修改配置后，在应用之前先验证更改。

至少运行：

```bash
nix flake check
```

如果合适，还要评估或构建受影响的系统：

```bash
nix build .#nixosConfigurations.<host>.config.system.build.toplevel
```

使用 `flake.nix` 中的实际主机名。

如果验证失败：
1. 检查错误；
2. 判断失败是否由该更改引起；
3. 如果合适，修复配置；
4. 再次运行验证。

不要隐藏或忽视验证失败。

## Git

使用 Git 检查和审阅变更。

在完成任务之前：

```bash
git status
git diff
```

最终 diff 应只包含与用户请求相关的改动。

不要：
- 重置或丢弃用户已有的更改；
- 除非明确要求，否则不要修改提交；
- 强制推送；
- 重写 Git 历史。

如果已存在无关的未提交更改，请保留它们。

## 应用配置

除非用户明确要求，否则不要自动运行会更改系统的命令。

尤其不要自动运行：

```bash
sudo nixos-rebuild switch
```

或修改运行中系统的其他命令。

当配置准备就绪时，报告用户可以运行的命令。

例如：

```bash
sudo nixos-rebuild switch --flake ~/Projects/nixos-config#desktop
sudo nixos-rebuild switch --flake ~/Projects/nixos-config#laptop
sudo nixos-rebuild switch --flake ~/Projects/nixos-config#server
sudo nixos-rebuild switch --flake ~/Projects/nixos-config#wsl
```

如果用户明确要求代理应用配置，请先验证配置，并在运行命令前清楚说明将会更改哪些内容。

## 硬件配置

将 `hardware-configuration.nix` 视为机器生成的配置。

除非任务特别要求，否则不要手动修改它。

不要将重新生成硬件配置作为无关任务的一部分。

## 机密信息

切勿将机密提交到此仓库。

请勿暴露或打印：
- 密码
- API 令牌
- SSH 私钥
- 私人凭据
- 加密密钥

如果仓库使用 `sops`、`agenix` 或其他机密管理系统，请遵循现有的机制。

请勿用明文值替换加密的机密。

## 软件包选择

在添加软件包之前：
1. 检查它是否已经安装；
2. 确定它属于系统软件包还是 Home Manager；
3. 遵循现有的软件包组织方式。

当存在合适的声明式选项时，优先使用它，而不是仅仅为了手动配置某个服务而安装软件包。

## 服务

启用服务时：
1. 检查现有服务配置；
2. 如果可用，使用 NixOS 原生模块；
3. 配置所需的最少选项；
4. 检查与现有服务的交互；
5. 验证生成的配置。

不要仅仅因为服务可能有用就启用它们。

## 用户交互

当请求的更改含义不明确且可能对系统产生重大影响时，应要求澄清，而不是猜测。

对于常规、低风险的配置更改，应沿用现有约定继续操作。

报告已完成的任务时，应总结：
- 更改了什么；
- 哪些文件发生了更改；
- 执行的验证；
- 正在运行的系统是否实际发生了更改。

## 重要原则

仓库是期望系统状态的唯一真实来源。

偏好：

```text
理解
    ↓
修改 Nix 配置
    ↓
格式化
    ↓
验证
    ↓
审查 diff
    ↓
应用
```

避免：

```text
运行任意命令
    ↓
修改实时系统
    ↓
尝试在 Nix 中复现这些更改
```

