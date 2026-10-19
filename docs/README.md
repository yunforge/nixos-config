# 文档索引

`docs/` 放各子系统的深度说明；根 `AGENTS.md` 只留总规则。动某个子系统前先读对应那篇，能省一轮反推。

| 改动主题 | 文档 | 对应代码 |
|------|------|----------|
| 仓库结构、选项与 module 分层约定、主机差异 | `docs/architecture.md` | `flake.nix`、`modules/`、`hosts/` |
| 平台适配坑位 / workaround / 待上游修复项 | `docs/quirks.md` | 各文件头部注释 |
| Fish、环境变量、PATH | `docs/fish.md` | `modules/home-manager/common/shell/fish.nix` |
| Ghostty 终端 | `docs/ghostty.md` | `modules/home-manager/gui/apps/shared/ghostty.nix` |
| 输入法（水杉、候选窗） | `docs/input.md` + `docs/themes.md` | `modules/nixos/desktop/default.nix`、`modules/nixos/core/default.nix`（msime overlay） |
| 桌面主题 / GTK / Qt / 图标 / 壁纸 | `docs/themes.md` | `modules/home-manager/gui/desktop/linux/themes/default.nix`、`modules/home-manager/gui/desktop/linux/niri/noctalia.nix` |
| Niri 快捷键、窗口与布局规则 | `docs/niri.md` | `modules/home-manager/gui/desktop/linux/niri/config/` + 生成 KDL 的 `gui/desktop/linux/niri/default.nix` |
| 装了哪些应用 | `docs/softwares.md` | `modules/home-manager/gui/apps/linux/`（含嵌入式工具链） |
| 开发工具链、Distrobox | `docs/environment.md` | `modules/home-manager/dev/languages/`、`modules/home-manager/common/tools/` |
| 角色组合（workstation / server / wsl / macbook） | `docs/architecture.md` 的「角色组合」 | `modules/*/profiles/`、`flake.nix` |
| tmux（含会话持久化） | `docs/tmux.md` | `modules/home-manager/common/tools/tmux.nix` + `tests/tmux-persistence.sh` |
| WinApps / Windows 虚拟机 / 探针直通 | `docs/winapps.md` | `modules/home-manager/gui/desktop/linux/winapps.nix`、`pkgs/windows-vm-media`、`modules/nixos/virtualization` |
| 部署、升级、垃圾回收 | `docs/manager.md` | 部署 / 升级 / GC 命令速查 |
