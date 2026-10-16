# Neovim 编辑器配置
#
# 配置树 nvim/ 复用 Omarchy 的 omarchy-nvim 包：LazyVim 官方 starter 骨架
# + Omarchy 的覆盖文件（lua/config、lua/plugins、plugin/after、lazyvim.json），
# 三处仅为适配 Nix 做了改动，见 nvim/lua/config/lazy.lua、nvim/lua/plugins/theme.lua
# 与 nvim/lua/plugins/lsp-from-nix.lua 的注释。~/.config/nvim 是指向 store 的只读符号链接，插件在首次启动时联网装进
# ~/.local/share/nvim（Omarchy 用约 116MiB 预缓存规避这一次下载，Nix 侧不做）。
{ lib, config, ... }:
let
  cfg = config.mengw.cli.editors.neovim;
  cliCfg = config.mengw.cli;
in
{
  options.mengw.cli.editors.neovim.enable = lib.mkEnableOption "Neovim（Omarchy 的 LazyVim 配置）" // {
    default = true;
  };

  config = lib.mkIf (cfg.enable && cliCfg.enable) {
    programs.neovim.enable = true;
    xdg.configFile = {
      "nvim".source = ./nvim;

      # 亮/暗跟随桌面（见 nvim/lua/plugins/theme.lua）：theme.lua 读这里翻软链的 mode 文件
      # 来设 vim.o.background，catppuccin 的 flavour="auto" 据此在 frappe / latte 之间选。
      # nvim 在启动时读，运行中的实例要重进（或 :colorscheme catppuccin）。
      "theme-variants/nvim/dark.lua".text = ''return "dark"'';
      "theme-variants/nvim/light.lua".text = ''return "light"'';
      # 初始值 = 暗色（与改造前一致）：rebuild 后被还原，登录时 theme-apply 再纠正。
      # force：这个软链归 theme-apply 接管（按 mode 指到 dark/light 变体），不跳过碰撞
      # 检查的话，下次 rebuild 会判成外来文件「would be clobbered」而整份激活失败。
      "theme-variants/nvim/mode.lua" = {
        text = ''return "dark"'';
        force = true;
      };
    };

    mengw.appearance.switchTargets = [
      {
        live = ".config/theme-variants/nvim/mode.lua";
        dark = ".config/theme-variants/nvim/dark.lua";
        light = ".config/theme-variants/nvim/light.lua";
      }
    ];
  };
}
