{
  lib,
  config,
  pkgs,
  ...
}:
let
  cfg = config.myHome.cli.dev.others;
  devCfg = config.myHome.dev;
in
{
  options.myHome.cli.dev.others.enable = lib.mkOption {
    type = lib.types.bool;
    default = true;
    description = "启用其他语言的开发环境（LSP、格式化工具等）";
  };

  config = lib.mkIf (cfg.enable && devCfg.enable) {
    # 其他语言开发工具
    home.packages = with pkgs; [
      # === bash ===
      bash-language-server # bash lsp
      shellcheck # 诊断
      shfmt # 格式化

      fish-lsp # fish lsp

      # === kdl ===
      kdlfmt # kdl fmt

      # === html/css/json/eslint ===
      vscode-langservers-extracted # html/json/css/scss/js/ts lsp
      eslint

      # === yaml ===
      yaml-language-server # yaml lsp

      # === docker ===
      docker-compose-language-service # docker compose lsp
      dockerfile-language-server # dockerfile lsp（LazyVim 的 lang.docker extra 需要）

      # === lua ===
      lua-language-server # lua lsp
      stylua # Lua 格式化工具

      # === Nix ===
      nil # nix lsp
      nixfmt # nix fmt
      statix # nix linter（LazyVim 的 lang.nix extra 需要）

      # === markdown ===
      marksman # markdown lsp
      ltex-ls-plus # markdown lsp，提供拼写和语法检查

      # === Latex ===
      # texlive.combined.scheme-full
      # texlab # LaTeX 语言服务器
    ];
  };
}
