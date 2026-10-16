# Fish 主题 —— 由 Noctalia 渲染
# 注册处：modules/home-manager/gui/desktop/linux/niri/noctalia.nix 的 theme.templates.user.fish
# 部署到 ~/.config/fish/conf.d/noctalia-colors.fish，登录时被 fish 自动 source。
# 占位符 colors.terminal_* 取自当前 Noctalia 调色板的 terminal 16 色，
# 与 ghostty / btop / yazi 同源。
# 用 hex_stripped（不带 #）：fish 的 set_color 只认裸十六进制或命名色，
# 给它 rgb_csv（如 64,160,43）会报 "set_color: 未知颜色"。
#
# 注意：~/.config/fish/conf.d/fish_frozen_theme.fish（fish_config 写的）
# 会设置同名变量，且按文件名顺序可能后加载而覆盖本文件 —— 若语法高亮不跟随，
# 删掉那个文件（见 docs/themes.md）。
set -g fish_color_normal {{ colors.terminal_foreground.default.hex_stripped }}
set -g fish_color_command {{ colors.terminal_normal_blue.default.hex_stripped }}
set -g fish_color_keyword {{ colors.terminal_normal_magenta.default.hex_stripped }}
set -g fish_color_quote {{ colors.terminal_normal_green.default.hex_stripped }}
set -g fish_color_redirection {{ colors.terminal_normal_magenta.default.hex_stripped }}
set -g fish_color_end {{ colors.terminal_normal_magenta.default.hex_stripped }}
set -g fish_color_error {{ colors.terminal_normal_red.default.hex_stripped }}
set -g fish_color_param {{ colors.terminal_foreground.default.hex_stripped }}
set -g fish_color_comment {{ colors.terminal_bright_black.default.hex_stripped }}
set -g fish_color_match --background={{ colors.terminal_normal_blue.default.hex_stripped }}
set -g fish_color_selection --background={{ colors.terminal_bright_black.default.hex_stripped }}
set -g fish_color_search_match --background={{ colors.terminal_bright_black.default.hex_stripped }}
set -g fish_color_operator {{ colors.terminal_normal_cyan.default.hex_stripped }}
set -g fish_color_escape {{ colors.terminal_normal_cyan.default.hex_stripped }}
set -g fish_color_autosuggestion {{ colors.terminal_bright_black.default.hex_stripped }}
set -g fish_color_cwd {{ colors.terminal_normal_green.default.hex_stripped }}
set -g fish_color_cwd_root {{ colors.terminal_normal_red.default.hex_stripped }}
set -g fish_color_user {{ colors.terminal_normal_white.default.hex_stripped }}
set -g fish_color_host {{ colors.terminal_normal_blue.default.hex_stripped }}
set -g fish_color_host_remote {{ colors.terminal_normal_green.default.hex_stripped }}
set -g fish_color_cancel {{ colors.terminal_normal_red.default.hex_stripped }}
set -g fish_color_history_current --bold
set -g fish_color_valid_path --underline
set -g fish_color_option {{ colors.terminal_bright_black.default.hex_stripped }}
set -g fish_color_status {{ colors.terminal_normal_red.default.hex_stripped }}
set -g fish_pager_color_prefix {{ colors.terminal_normal_cyan.default.hex_stripped }}
set -g fish_pager_color_completion {{ colors.terminal_foreground.default.hex_stripped }}
set -g fish_pager_color_description {{ colors.terminal_bright_black.default.hex_stripped }}
set -g fish_pager_color_selected_background --background={{ colors.terminal_normal_blue.default.hex_stripped }}
