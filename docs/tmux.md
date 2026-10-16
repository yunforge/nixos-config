# Tmux 终端复用器

配置位置：`modules/home-manager/common/tools/tmux.nix` + `tmux/tmux.conf`（按键布局取自 Omarchy；快照插件 tmux-resurrect / tmux-continuum 由 `tmux.nix` 的 `programs.tmux.plugins` 加载，不在 tmux.conf 里）。

前缀键：`Ctrl` + `b`。无前缀的 `Alt` / `Ctrl`+`Alt` 组合可直接操作窗口与面板，无需先按前缀。

## 面板 (Pane)

| 按键 | 功能 |
| --- | --- |
| `Prefix` + `h` / `Alt` + `Enter` | 上下分割 |
| `Prefix` + `v` / `Alt` + `Shift` + `Enter` | 左右分割 |
| `Prefix` + `x` / `Alt` + `Esc` | 关闭当前面板 |
| `Ctrl` + `Alt` + `←/→/↑/↓` | 左 / 右 / 上 / 下 切换面板焦点 |
| `Ctrl` + `Alt` + `Shift` + `←/→/↑/↓` | 左 / 右 / 上 / 下 调整面板大小（步进 5） |

## 窗口 (Window)

| 按键 | 功能 |
| --- | --- |
| `Prefix` + `c` | 新建窗口（继承当前路径） |
| `Prefix` + `r` | 重命名窗口 |
| `Prefix` + `k` | 关闭窗口 |
| `Alt` + `1`…`9` | 切换到第 N 个窗口 |
| `Alt` + `←` / `→` | 上一个 / 下一个窗口 |
| `Alt` + `Shift` + `←` / `→` | 向左 / 向右移动窗口 |

## 会话 (Session)

| 按键 | 功能 |
| --- | --- |
| `Prefix` + `C` | 新建会话 |
| `Prefix` + `R` | 重命名会话 |
| `Prefix` + `K` | 关闭会话 |
| `Prefix` + `P` / `N` | 上一个 / 下一个会话 |
| `Alt` + `↑` / `↓` | 上一个 / 下一个会话 |
| `Prefix` + `d` | 分离（detach）当前会话 |

## 复制模式

| 按键 | 功能 |
| --- | --- |
| `Prefix` + `[` | 进入复制模式 |
| `v` | 开始选择 |
| `y` | 复制并退出 |

## 其他

| 按键 | 功能 |
| --- | --- |
| `Prefix` + `q` | 重载配置 |
| `Prefix` + `?` | 弹出全部快捷键列表 |
| `Prefix` + `z` | 最大化 / 还原当前面板 |

重新连接会话：`tmux attach -t <会话名>`（或 `tmux ls` 查看后附加）。

---

# 会话持久化

重启（或注销）后把会话原样带回来：会话 / 窗口 / 面板 / 精确布局 / 每个面板的 cwd /
窗口名，可选连**面板滚动历史**和**白名单程序**（默认 `nvim` `vim` `ssh` `tio`）。

开关与参数（定义在 `modules/home-manager/common/tools/tmux.nix`，默认开启）：

```nix
mengw.cli.tools.tmux.persistence = {
  enable = true;                 # 总开关
  autoRestore = true;            # 手工启动 server 时也让 continuum 尽力恢复
  restoreProcesses = [ "~nvim->nvim *" ];   # 额外要重启的程序（写法见下）
  capturePaneContents = false;   # 是否连滚动历史一起存（快照会随 history-limit 变大）
  saveInterval = 15;             # 定时保存间隔（分钟）
  directory = "${config.home.homeDirectory}/.local/state/tmux/resurrect";
  loginTarget = "graphical-session.target"; # 无图形会话的主机（WSL）可改 default.target
};
```

## 什么时候会存、什么时候会恢复

```
覆盖              ①登录(tmux-persist.service)  ②定时(tmux-persist-save.timer)
                 ③注销/关机(ExecStop)
存  ──►  <快照目录>/last（纯文本）+ 可选 pane_contents.tar.gz
恢复 ◄──  ①登录时【显式】调用 resurrect 恢复   ②手工启动 server 时 continuum 尽力恢复
```

| 按键 / 命令 | 作用 |
| --- | --- |
| `tmux-persist-save` | 命令行手动保存（没有 server 时安全跳过） |
| `tmux-persist-start` | 手动跑一次"登录恢复"（排错用） |
| `systemctl --user status tmux-persist.service` | 看登录恢复/注销保存的日志 |
| `tests/tmux-persistence.sh` | 隔离 socket 上的冒烟测试（存→防误清→重建→登录路径→注销路径） |

恢复后你所在的位置取决于快照里有什么：登录时若快照里存在名为 `main` 的会话，它会被
直接复用；否则恢复完就收掉占位会话。日常建议固定一个主页会话：
`tmux new -A -s main`（不存在就建、存在就接入），重启后能落到同一个会话上。

## 本仓库踩过的坑（改这块前先看）

- **别用 continuum 的自动恢复做登录恢复**：它判断"是否已有别的 server"的方式是数
  `ps -u $UID | grep '^tmux'` 的**进程数**，任何同时存在的 tmux 客户端（包括探测脚本
  自己）都会被当成第二个 server，于是它静默跳过恢复。实测：机器上挂有两个游离的
  `tmux new/attach` 客户端进程时，登录恢复 100% 不生效。故登录路径改为在
  `tmux-persist-start` 里**显式**调用 `resurrect/scripts/restore.sh`。
- **NixOS + fish 下"恢复运行中的程序"必须带双引号写白名单**：fish 传给 `execve` 的
  `argv[0]` 是解析后的绝对路径（`/nix/store/.../bin/nvim`），resurrect 默认按词匹配
  `nvim` 永远匹配不上；而 `~nvim->nvim *` 这种写法若不带内层双引号，`*` 会被
  resurrect 内部的 `eval set` 当通配符拆词、参数占位符失效。故条目统一写成
  `'"~nvim->nvim *"'`（模块里已自动加引号）。
- **别把 `@resurrect-processes` 设成 `:all:`**：它会把当时所有前台进程原样重放，
  官方文档明确警告（`sudo mkfs` 之类会被重放）。
- **无 server 时保存会毁快照**：`resurrect/scripts/save.sh` 不检查 server 是否存在，
  此时 dump 全空、`files_differ` 判为"快照变了"，会把**空快照**写成 `last`。所以
  `tmux-persist-save` 先 `list-sessions` 探测，没有 server 就直接跳过。
- **插件在 HM 生成配置里的位置**：`programs.tmux.plugins` 排在 `extraConfig`（即
  `tmux.conf`）**之前**，所以 `tmux.conf` 末尾的 `set -g status-right` 会覆盖掉
  continuum 注入的自动保存钩子 → 本仓库因此把 `@continuum-save-interval` 设为 `0`，
  自动保存交给 systemd timer（不依赖状态栏重绘，也没有这段隐性耦合）。
- **`~/.local/state/tmux/resurrect` 与 `~/.tmux/resurrect`**：后者是 resurrect 上游默认
  位置，本仓库按 XDG 收到了前者；`@resurrect-dir` 是唯一权威，脚本日志打印的是它。
- **systemd 单元不要叫 `tmux.service`**：continuum 在 `@continuum-boot` 关闭时会执行
  `systemctl --user disable tmux.service`，会去动 HM 生成的软链，故本仓库用
  `tmux-persist.service`。
- **`resurrect` 脚本的 shebang 是 `/usr/bin/env bash`**（NixOS 无 `/usr/bin`）：tmux 的
  `run-shell` 靠 shell 的 ENOEXEC 回退能跑，systemd 的 `Exec*` 是直接 `execve`、没有
  回退，所以封装脚本一律用 `${pkgs.bash}` 显式调用它们。
