# AI Agent 能力聚合入口（所有主机共享）
#
# 把「给 AI/Agent 用的用户环境」收在一处：AI 编程 CLI 工具链（Claude Code /
# pi-coding-agent / Codex / herdr 等）与它们的 shell 集成（`cc` 别名、agent
# 侧 API 密钥的本地文件 source）。与普通 CLI/TUI 工具（tmux / fastfetch …）
# 分层，便于以后把 MCP / skill / agent-desktop / agent-browser 等 Agent 侧
# 配置继续往这里聚。
#
# 门控：myHome.ai.enable（与 myHome.cli.enable 解耦）。默认 true 且所有主机
# （含 server / wsl / macbook）都装——与迁移前「放在 common/tools 里、所有主机
# 都装」的行为一致。想在某台机器整体关掉 Agent 能力时用 lib.mkForce false。
#
# 不在本层的 Agent 相关内容（有意保留在原处，属对应子系统职责）：
#   - agent-browser / Playwright 的 Chrome 共享库 → modules/nixos/core/default.nix
#     的 programs.nix-ld.libraries（系统级 nix-ld 补齐，不是用户态包）
#
# `claude-cli://` 深链的 MIME 默认程序不写死在仓库里（桌面默认应用统一由
# 桌面「默认应用」设置自行管理）；该 handler 是唯一候选时深链仍能打开。
{
  lib,
  config,
  ...
}:
{
  options.myHome.ai.enable = lib.mkOption {
    type = lib.types.bool;
    default = true;
    description = ''
      启用 AI Agent 用户环境（AI 编程 CLI 工具与 shell 集成）。
      与 myHome.cli.enable 解耦：可在保留普通 CLI 工具的同时单独关闭 Agent 能力。
    '';
  };

  imports = [
    ./tools.nix
  ];

  config = lib.mkIf config.myHome.ai.enable {
    # 具体包与 shell 集成分列在 tools.nix；此层只定义开关并聚合。
  };
}
