# Fish Shell

配置位置：`modules/home-manager/common/shell/fish.nix`。

终端默认英文环境，`EDITOR=nvim`，`LC_ALL=en_US.UTF-8`。

## 系统部署别名

| 别名 | 功能 |
|------|--------|
| `updatedp` | 重建 desktop 主机 |
| `updatedplog` | 重建 desktop 并输出详细构建日志 |
| `updatelp` | 重建 laptop 主机 |
| `updatelplog` | 重建 laptop 并输出详细构建日志 |
| `updatewsl` | 重建 WSL 主机 |

## 文件与目录

`ls` / `ll` / `la` / `lla` / `lt` 的参数（icons / colors / git / 排序）来自 `programs.eza`，
配置在 `modules/home-manager/common/shell/default.nix`。模块生成的别名体调 `eza`，参数挂在
`eza` 这条别名上，所以改参数去那里，不要在 `fish.nix` 重写整条别名。

| 别名 | 功能 |
|------|--------|
| `..` / `...` | 上级 / 上上级目录 |
| `ls` / `ll` / `la` / `lla` | eza 增强列表 |
| `lt` | 目录树 |
| `fd` | fd 带 `--hidden`（点文件默认可见，由 `programs.fd.hidden` 生成） |

> `bat` / `cat` 不再设别名：bat 的行为统一由 `programs.bat.config` 决定（见
> `modules/home-manager/common/shell/default.nix`），`cat` 即系统 cat。

## Git

| 别名 | 功能 |
|------|--------|
| `gs` | git status |
| `ga` | git add |
| `gc` | git commit |
| `gp` | git push |
| `gl` | git log 图形化 |

## 磁盘

| 别名 | 功能 |
|------|--------|
| `df` | duf 仅本地磁盘 |
| `duf` | duf 按用量排序 |
| `dufall` | duf 全部磁盘 |
| `dufjson` | duf JSON 输出 |

## 其他

| 别名 / 命令 | 功能 |
|------|--------|
| `cc` | Claude Code（跳过权限确认） |
| `arch` / `ubuntu` | distrobox 进入对应发行版容器 |
| `cd` / `cdi` | zoxide 跳转 / 交互式选择（由 `programs.zoxide` 的 `--cmd cd` 接管内置 `cd`） |
| `zquery` | zoxide 查询历史目录 |
| `Ctrl` + `o` | 命令选择器（fzf 模糊选择常用命令） |
| `Ctrl` + `g` / `rgf [rg 参数]` | 全文模糊搜索（rg + fzf）：`rgf TODO` 直接搜，`rgf` 不带参数会先提示 pattern；回车用 nvim 跳到命中行，bat 预览高亮该行。按文件名找仍用 `Ctrl` + `t`（fd） |
| `cheat <provider>` | 快捷键速查表（fish / tmux / vim） |
| `lg` | lazygit（由 `programs.lazygit` 的 fish 集成提供，退出时 `cd` 到刚才操作过的目录） |

## zoxide

`programs.zoxide`（配置在 `modules/home-manager/common/shell/default.nix`）负责装包并注入
shell 集成与补全，`home.packages` 里不再重复列。

`options = [ "--cmd cd" ]` 让 zoxide **接管内置 `cd`**（不带该选项时才是 `z` / `zi`）：
`cd <真实目录>` / `cd ..` / `cd -` 照常走 fish 原生的 `__zoxide_cd_internal`，只有非目录
参数才交给 zoxide 查库，故 `cd nixos` 这类关键字跳转可用、且 `..` / `...` 别名不受影响。
交互式选择器相应改名 `cdi`。

`_ZO_EXCLUDE_DIRS` 由 `home.sessionVariables` 写入，排掉系统目录，免得补全候选里混进
`/usr/bin`、`/nix/store`、`/var/log` 这类不会 cd 进去的路径。注意**没有排 `/etc`**：
好处是 `/etc/nixos`（真实存在、偶尔要进去看的目录）能入库（排掉 `/etc*` 它就完全进不来），
代价是 `/etc/fonts`、`/etc/X11/xorg.conf.d` 之类也会进候选。且 `cd nixos` 一般仍跳去
`~/Projects/nixos-config`（访问频次高、分数高），要用 `/etc/nixos` 时直接 `cd /etc/nixos`
或看 `cdi` 候选。
两个实测坑：

- 设置该变量是**替换** zoxide 内置的 `$HOME` 默认值，不是追加，所以 `$HOME` 自身要显式写回；
- zoxide **不展开** `$HOME` / `~`，只认绝对路径（写 `$HOME` 字面量会静默失效）。
  通配符 `*` 跨越 `/`，故 `/usr*` 同时覆盖 `/usr` 与其全部子目录。

`$HOME` 只排自身，`~/Projects` 这类子目录仍会入库。

`_ZO_FZF_OPTS`（同一模块）给 `cdi` 加目录预览：右侧 50% 用
`eza --tree --level=1` 展开候选目录。语义上有个大坑：zoxide 0.10 起该变量是当作
**FZF_DEFAULT_OPTS 整体替换**传给 fzf，而不是追加。一旦设置，zoxide 内置的
`--exact` / `--no-sort` / `--height=45%` 等参数**和自带的 ls 预览**全部失效，
`programs.fzf` 的全局 `FZF_DEFAULT_OPTS` 也被顶掉（`--no-sort` 没了会让候选按
路径长度重排、丢掉 frecency 顺序）。所以配置里把 zoxide 内置默认参数抄了一份，
只换预览命令；升级 zoxide 后若上游默认有变，要对照源码 `get_fzf()` 跟一下。
两个易错点：

- 占位符必须 `{2..}` 而不是 `{}`：zoxide 每行是 `<score>\t<path>`（fzf 侧
  `--delimiter` 为制表符、`--nth=2`），`{}` 会把分数一起传给 eza；
- 预览命令的 stdout 是管道不是 TTY，eza 的 `auto` 会**连图标和颜色一起关掉**，
  必须写 `always`；
- 预览参数只能用**单引号**：HM 生成的 `hm-session-vars.sh` 用双引号包整个值，
  内层再写双引号会把值截断，babelfish 转 fish 时构建期报 `invalid var name`。

## PATH 与工具可见性

`programs.fish.shellInit` 开头有一行 `fish_add_path ${config.home.profileDirectory}/bin`
（见 `modules/home-manager/common/shell/fish.nix`）。原因：Home Manager 开了
`useUserPackages`，fzf / fnm / eza / zoxide / bat / fd 等被装进 per-user profile
（`/etc/profiles/per-user/<user>/bin`）；而 fish **不读 `/etc/profile`**，TTY / SSH 等
登录式 shell 继承的 PATH 里往往没有这个目录，就会报 `fish: Unknown command: fnm`、
`fzf was not found in path.` 之类的启动错误。显式补进 PATH 后，图形 / TTY / SSH 各种
启动方式都能解析到这些 HM 包。

`fnm env` 初始化用 `fnm env --use-on-cd --shell fish | source`：`--shell fish` 显式指定
shell，**不依赖进程树推断**——Tern 等启动器下进程树里没有可识别的 shell，缺省会报
`Can't infer shell!`；外层再用 `type -q fnm` 兜底，容器等没有 fnm 的环境不会在启动时刷错误。

Tern 这类启动器用「干净环境 + `fish -l`」起 shell，只传
`/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin`，而 fish 不读 `/etc/profile`，所以
podman / sudo 等系统命令在 Tern 面板里不可见。`shellInit` 在 Linux 上因此还会补回
`/run/wrappers/bin` 与 `/run/current-system/sw/bin`；`/nix/var/nix/profiles/default/bin`
在本机不存在，`fish_add_path` 会自动忽略不存在的目录。
