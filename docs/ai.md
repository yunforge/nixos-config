# AI Agent 用户环境

`modules/home-manager/common/ai/` 是「给 AI / Agent 用」的用户环境聚合层，
与普通 CLI/TUI 工具（`common/tools/`）分层，便于把 Agent 侧配置集中在一处。

## 目录与职责

| 文件 | 职责 |
|------|------|
| `common/ai/default.nix` | 聚合入口：定义 `myHome.ai.enable` 开关，导入 `tools.nix` |
| `common/ai/tools.nix` | AI 编程 CLI 工具包 + shell 集成（`cc` 别名、atria 密钥 source） |

由 `common/default.nix` 导入，所有主机（desktop / laptop / server / wsl / macbook）共享。

## 门控

`myHome.ai.enable`（默认 `true`，与 `myHome.cli.enable` **解耦**）。
保留普通 CLI 工具的同时，可用 `lib.mkForce false` 单独关掉某台机器的 Agent 能力。

> 迁移前这些工具混在 `common/tools/default.nix` 的 `home.packages` 里、随
> `myHome.cli.enable` 开关；现收进本层，行为对现有主机保持不变（仍全主机安装）。

## 当前收在本层的内容

- **CLI 工具**：`claude-code`（提供 `claude`，`cc` = `claude --dangerously-skip-permissions`）、
  `pi-coding-agent`、`codex`、`herdr`。
- **shell 集成**：`cc` 别名；登录时 source `~/.config/atria/env.fish`（agent 侧 API 密钥，
  放在 git 外、不入库）。

## 有意留在原处的 Agent 相关内容

以下也属 Agent 生态，但职责归对应子系统，**不**搬进 `common/ai/`：

| 内容 | 位置 | 不搬的理由 |
|------|------|-----------|
| agent-browser / Playwright 的 Chrome 共享库 | `modules/nixos/core/default.nix` 的 `programs.nix-ld.libraries` | 系统级 nix-ld 补齐，不是用户态包；非 HM 层 |

注：`claude-cli://` 深链的 MIME 默认程序不写死在仓库里（桌面默认应用统一由
桌面「默认应用」设置自行管理，不随 AI 层声明）。

## 尚未纳入仓库的 Agent 配置（$HOME 下、被 .gitignore 忽略）

这些目前不由 Nix 声明式管理，散在用户 home 里：

- MCP 服务器配置：仓库根的 `.mcp.json`（如 `nixos` = `uvx mcp-nixos`）+ `.claude/settings.local.json`
- skill：`~/.agents/skills/`（`agent-desktop` / `commit` / `study`），`~/.claude/skills/` 里是软链
- `agent-desktop` / `agent-browser` 工具自身的安装与配置

若要声明式接管，需要先决定这些内容如何落库（与 `.gitignore` 的 `/.agents/`、`/.claude/`
条目冲突），再在 `common/ai/` 下按 `home.file` / `xdg.dataFile` 托管——属于后续独立工作。
