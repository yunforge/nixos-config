# 系统管理

## 部署新配置

```bash
# desktop 主机（Niri 桌面）
sudo nixos-rebuild switch --flake ~/Projects/nixos-config#desktop

# laptop 主机（Niri 桌面）
sudo nixos-rebuild switch --flake ~/Projects/nixos-config#laptop

# server 主机（无桌面，首次部署前需在目标机器生成 hardware-configuration.nix，见 docs/architecture.md）
sudo nixos-rebuild switch --flake ~/Projects/nixos-config#server

# WSL
sudo nixos-rebuild switch --flake ~/Projects/nixos-config#wsl

# macOS
darwin-rebuild switch --flake ~/Projects/nixos-config#macbook
```

部署成功后会生成新系统环境，旧环境保留并加入 systemd-boot 启动项（最多保留 10 个，见 `boot.loader.systemd-boot.configurationLimit`）。

> Fish 别名：`updatedp` / `updatedplog` / `updatelp` / `updatelplog` / `updatewsl`

## 装机后的一次性步骤

有一类状态由 Noctalia 自己持有（`~/.local/state/noctalia/settings.toml`）且**运行时覆盖 Nix 声明**，`switch` 不会替你改。新机器上跑一次，已经跑过的不必重复：

```bash
# 壁纸：把所有输出与 wallpaper.default.path 一起写进 settings.toml
noctalia msg wallpaper-set ~/Pictures/wallpaper/默认集/city-street.jpg

# 调色板：让 theme.source 真正生效（改后也可在 Noctalia 外观面板选一次）
noctalia msg color-scheme-set custom mactahoe
noctalia msg color-scheme-get   # 应回：custom mactahoe
```

bar 布局的**四项**（`bar.default` 的 opacity / start / center / end）已声明在 `programs.noctalia.settings`，但它们**运行时状态优先**：state 里已有的同键会遮蔽 Nix 声明。首次要让它生效，把 state 里这四行删掉（其余键都别动，尤其 `[plugin_settings."coder/deepseek_usage"]` 里的 api_key）：

```bash
# ~/.local/state/noctalia/settings.toml 的 [bar.default] 段，删这四行：
#   background_opacity / start / center / end
noctalia config validate ~/.config/noctalia/config.toml   # 删完校验一下
# 然后注销重登（壳层重启才会重新读 config.toml）
```

之后在 GUI 里改这几项会重新写回 state、再次遮蔽它——与 `theme.source` 同一个模式。

还有一项**只能在 GUI 里关**：cat 小部件的 `rave_mode`（动画在静止的壳层里是持续噪音）。它不能声明——小部件本身（id 与 type）由 GUI 持有，只声明它的一个子键会生成一个无 `type` 的 `[widget.cat]` 段，`noctalia config validate` 会报 `unrecognized widget type "cat"`。

## 排错

```bash
# 构建时输出详细日志
sudo nixos-rebuild switch --flake ~/Projects/nixos-config#desktop --show-trace --print-build-logs --verbose
```

## 更新 flake 锁定文件

```bash
nix flake update          # 更新所有输入
nix flake update nixpkgs  # 只更新单个输入
```

## 查看与清理历史数据

```bash
# 查询当前可用所有历史版本
nix profile history --profile /nix/var/nix/profiles/system

# 清理 7 天之前的所有历史版本
sudo nix profile wipe-history --older-than 7d --profile /nix/var/nix/profiles/system

# 删除所有未使用的包
sudo nix-collect-garbage --delete-old

# 存储优化
nix store optimise
```

> 系统已配置自动每周 GC（`--delete-older-than 7d`）与自动升级（`system.autoUpgrade`）。

## 其他常用命令

```bash
# 格式化所有 Nix 文件（nixfmt，RFC 166 风格；裸调用即递归格式化全树）
nix fmt

# 只格式化指定文件
nix fmt path/to/file.nix

# 进入开发环境（git + treefmt/nixfmt）
nix develop
```
