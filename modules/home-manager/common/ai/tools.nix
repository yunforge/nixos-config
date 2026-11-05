# AI Agent CLI 工具与 shell 集成
#
# 门控：myHome.ai.enable（见同目录 default.nix）。本文件只放「装什么包」与
# 「shell 侧怎么接」，具体开关在 default.nix 定义。
{
  lib,
  config,
  pkgs,
  ...
}:
let
  cfg = config.myHome.ai;
in
{
  config = lib.mkIf cfg.enable {
    # AI 编程 CLI 工具链。
    # 迁移说明：原先这些包混在 common/tools/default.nix 的 home.packages 里，
    # 现收进本层。claude-code 提供 `claude`（`cc` 别名见下）；pi-coding-agent /
    # codex / herdr 是其它 Agent 运行时。Linux / macOS 的 nixpkgs 都提供这些
    # 属性，server / wsl 也照装（与迁移前一致）。
    home.packages = with pkgs; [
      claude-code
      pi-coding-agent
      codex
      herdr
    ];

    # shell 集成用鱼。fish 本身由 common/shell 管理；这里只往鱼里追加
    # Agent 专属的别名与密钥 source，不接管整份 fish 配置。
    programs.fish = {
      # `cc` = 免确认的 Claude Code（`--dangerously-skip-permissions`）。
      shellAliases = {
        cc = "claude --dangerously-skip-permissions";
      };

      # Agent 侧 API 密钥：存放在 git 外的本地文件（不入库，见 .gitignore
      # 与 AGENTS.md「机密信息」），存在时 source 进来。
      interactiveShellInit = ''
        # API 密钥存放于 git 外的本地文件，避免明文入库
        set -l atria_env ~/.config/atria/env.fish
        if test -f $atria_env
          source $atria_env
        end
      '';
    };
  };
}
