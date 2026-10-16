## 资源

- [查找包](https://search.nixos.org/packages)
- [查找设置](https://search.nixos.org/options)
- [更快的搜索](https://nixsearch.thekoppe.com/)
- [NixOS 中文](https://nixos-cn.org/manual/)
- [NixOS & Flakes Book](https://nixos-and-flakes.thiscute.world/zh/introduction/)
- [NixOS 中文论坛](https://discourse.nixos.org/c/learn/chinese/55)
- [Awesome-Nix](https://github.com/nix-community/awesome-nix)

## 部署新配置

```bash
# NixOS 笔记本
sudo nixos-rebuild switch --flake ~/Projects/nixos-config#laptop

# NixOS 主机
sudo nixos-rebuild switch --flake ~/Projects/nixos-config#desktop

# NixOS 服务器
sudo nixos-rebuild switch --flake ~/Projects/nixos-config#server

# WSL
sudo nixos-rebuild switch --flake ~/Projects/nixos-config#wsl

# macOS
darwin-rebuild switch --flake ~/Projects/nixos-config#macbook
```
此命令会根据当前配置文件生成一个新的系统环境，并将新的系统环境设为默认环境。

上一个系统环境也会保留，并加入 systemd-boot 启动项（最多保留 10 个，见 `boot.loader.systemd-boot.configurationLimit`）。

## 常用命令

```bash
# 更新 flake.lock
nix flake update

# 删除所有当前系统未使用的包
sudo nix-collect-garbage --delete-old

# 存储优化
nix store optimise
```

## 我的配置

- Shell：[Fish](https://github.com/fish-shell/fish-shell)
- 终端：[Ghostty](https://ghostty.org/)
- 终端编辑器：[Neovim](https://github.com/neovim/neovim)
