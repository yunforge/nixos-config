#!/usr/bin/env bash
# tmux 会话持久化冒烟测试
#
# 目的：在**完全隔离**的 socket / 快照目录上验证「快照写入 → 无 server 时不误清快照 →
# 会话按快照重建（含每个面板的 cwd 与白名单程序）」，即模块里那套插件配置与
# tmux-persist-save 封装脚本的真实行为。不碰用户当前正在跑的 tmux server，
# 也不写真实快照目录。
#
# 用法（需在 `nixos-rebuild switch` 之后跑，因为它读的是已生成的配置与脚本）：
#   ./tests/tmux-persistence.sh [配置路径] [保存脚本] [登录脚本] [注销脚本]
# 默认：~/.config/tmux/tmux.conf 与 PATH 上的 tmux-persist-{save,start,stop}
#
# 退出码：0 全部通过；1 有断言失败。
set -uo pipefail

conf=${1:-"$HOME/.config/tmux/tmux.conf"}
save_bin=${2:-tmux-persist-save}
start_bin=${3:-tmux-persist-start}
stop_bin=${4:-tmux-persist-stop}

fail=0
pass_count=0

ok() {
  printf '  \033[32mPASS\033[0m %s\n' "$1"
  pass_count=$((pass_count + 1))
}

bad() {
  printf '  \033[31mFAIL\033[0m %s\n' "$1"
  fail=$((fail + 1))
}

step() {
  printf '\n=== %s ===\n' "$1"
}

# 断言辅助：$1 描述，$2 期望值，$3 实际值
assert_eq() {
  if [ "$2" = "$3" ]; then ok "$1（$3）"; else bad "$1：期望 [$2]，实际 [$3]"; fi
}

assert_contains() {
  if printf '%s' "$2" | grep -q "$3"; then ok "$1"; else bad "$1：在 [$2] 里找不到 [$3]"; fi
}

refute_contains() {
  if printf '%s' "$2" | grep -q "$3"; then bad "$1：不该出现 [$3]，实际 [$2]"; else ok "$1"; fi
}

# ── 环境准备 ──────────────────────────────────────────────
for dep in tmux grep; do
  command -v "$dep" >/dev/null 2>&1 || {
    echo "缺少依赖：$dep" >&2
    exit 1
  }
done
[ -f "$conf" ] || {
  echo "找不到已生成的配置：$conf" >&2
  echo "先执行 nixos-rebuild switch（或用第一个参数指定配置路径）" >&2
  exit 1
}
for bin in "$save_bin" "$start_bin" "$stop_bin"; do
  command -v "$bin" >/dev/null 2>&1 || {
    echo "找不到 $bin（应来自 modules/home-manager/common/tools/tmux.nix 的 home.packages）" >&2
    exit 1
  }
done

# 关键：清掉 TMUX/TMUX_PANE，否则本脚本会连到调用者当前的 server 上；
# 再把自己关进独立 TMUX_TMPDIR，与真实 server 彻底隔离。
unset TMUX TMUX_PANE
work=$(mktemp -d /tmp/tmux-persist-test.XXXXXX)
export TMUX_TMPDIR="$work/run"
mkdir -p "$TMUX_TMPDIR" "$work/wd1" "$work/wd2" "$work/resurrect"

# 复刻真实配置，只覆盖快照目录（配置里同名的 set 在文件末尾会生效）
test_conf="$work/tmux.conf"
cat "$conf" >"$test_conf"
printf "\n# 测试覆盖：把快照目录指到沙箱\nset -g @resurrect-dir '%s'\n" "$work/resurrect" >>"$test_conf"

tmux_t() { tmux -f "$test_conf" "$@"; }
save_t() { TMUX_TMPDIR="$TMUX_TMPDIR" "$save_bin"; }

cleanup() {
  tmux_t kill-server >/dev/null 2>&1
  rm -rf "$work"
}
trap cleanup EXIT

snapshot="$work/resurrect/last"

echo "沙箱：$work"
echo "配置：$conf（覆盖 @resurrect-dir 后使用）"
grep -m1 -oE '/nix/store/[^ ]*/tmux-plugins/resurrect/resurrect\.tmux' "$test_conf" >/dev/null || {
  echo "警告：配置里没找到 resurrect 插件的 run-shell，后续断言可能失败" >&2
}

# ── T1 配置内容符合预期 ───────────────────────────────────
step "T1 已生成的配置包含持久化设置"
assert_contains "@resurrect-dir 指向 XDG state 目录" "$(cat "$test_conf")" "@resurrect-dir"
assert_contains "@resurrect-processes 带双引号的参数占位符写法" "$(cat "$test_conf")" '@resurrect-processes .*->.* \*"'
assert_contains "continuum 自动恢复已打开" "$(cat "$test_conf")" "@continuum-restore 'on'"
assert_contains "continuum 自带状态栏保存已关闭（改由 systemd timer）" "$(cat "$test_conf")" "@continuum-save-interval '0'"

# ── T2 保存：会话/窗口/面板/cwd 落盘 ─────────────────────
step "T2 保存快照"
tmux_t new-session -d -s work -c "$work/wd1"
tmux_t new-window -t work -c "$work/wd2"
tmux_t split-window -h -t work:2 -c "$work/wd2"
tmux_t send-keys -t work:2.1 "nvim -u NONE notes.md" Enter
sleep 2

save_t
sleep 1
[ -f "$snapshot" ] && ok "快照文件已生成：$snapshot" || bad "快照文件未生成"

snap=$(cat "$snapshot" 2>/dev/null || echo "")
assert_contains "快照里有会话 work" "$snap" "pane	work	"
assert_contains "快照记录了窗口 1 的 cwd" "$snap" "$work/wd1"
assert_contains "快照记录了窗口 2 的 cwd" "$snap" "$work/wd2"
assert_contains "快照记录了 nvim 进程" "$snap" "pane	work	2	1	:\*	1	.*nvim"

# ── T3 无 server 时保存必须跳过（否则空快照会覆盖 last） ──
step "T3 无 tmux server 时保存不得破坏快照"
before=$(md5sum "$snapshot" | cut -d' ' -f1)
tmux_t kill-server
sleep 1
save_out=$(save_t 2>&1)
after=$(md5sum "$snapshot" | cut -d' ' -f1)
assert_eq "快照文件未被改写" "$before" "$after"
assert_contains "保存脚本写明了跳过原因" "$save_out" "没有运行中的 tmux server"

# ── T4 重建：会话/窗口/面板数/cwd/程序 ───────────────────
step "T4 按快照重建会话"
resurrect_tmux=$(grep -m1 -oE '/nix/store/[^ ]*/tmux-plugins/resurrect/resurrect\.tmux' "$test_conf")
restore_script=${resurrect_tmux%/*}/scripts/restore.sh

tmux_t new-session -d -s __scratch__
if [ -x "$restore_script" ] || [ -f "$restore_script" ]; then
  tmux_t run-shell "$restore_script"
else
  bad "找不到 restore 脚本：$restore_script"
fi

for _ in $(seq 1 20); do
  tmux_t has-session -t work 2>/dev/null && break
  sleep 0.5
done
sleep 1

sessions=$(tmux_t list-sessions -F '#{session_name}' 2>/dev/null | tr '\n' ' ')
assert_contains "会话 work 已恢复" "$sessions" "work"

panes=$(tmux_t list-panes -a -F '#{session_name}:#{window_index}.#{pane_index} #{pane_current_path} #{pane_current_command}' 2>/dev/null)
assert_contains "work:1 的 cwd 恢复正确" "$panes" "work:1.1 $work/wd1"
assert_contains "work:2 的 cwd 恢复正确" "$panes" "work:2.2 $work/wd2"
assert_contains "nvim 已在面板里被重新拉起" "$panes" "nvim"

# ── T5 登录路径：tmux-persist-start 拉起 server 并按快照恢复 ──
#
# 用真实的登录脚本（systemd 单元里 ExecStart 跑的那个）来验，且把 HOME 指到
# 沙箱，让 tmux 读沙箱配置。不依赖 continuum 的自动恢复：它的「多 server」启发式
# 只数 tmux 进程，本机只要还挂着别的 tmux 客户端，它就会静默跳过（已实测）。
step "T5 登录脚本：拉起 server + 恢复会话（含白名单程序）"
tmux_t kill-server
sleep 1
rm -f "$snapshot"
tmux_t new-session -d -s solo -c "$work/wd2"
tmux_t send-keys -t solo "nvim -u NONE notes.md" Enter
sleep 2
save_t
sleep 1
tmux_t kill-server
sleep 1

mkdir -p "$work/home/.config/tmux"
cp "$test_conf" "$work/home/.config/tmux/tmux.conf"
if HOME="$work/home" XDG_CONFIG_HOME="$work/home/.config" "$start_bin" >"$work/start.log" 2>&1; then
  ok "tmux-persist-start 执行成功"
else
  bad "tmux-persist-start 执行失败：$(tail -2 "$work/start.log" | tr '\n' ' ')"
fi

sessions=$(tmux_t list-sessions -F '#{session_name}' 2>/dev/null | tr '\n' ' ')
assert_contains "会话 solo 已按快照恢复" "$sessions" "solo"
refute_contains "占位会话 main 已被收掉（快照里没有 main）" "$sessions" "main"

login_panes=$(tmux_t list-panes -a -F '#{session_name}:#{window_index}.#{pane_index} #{pane_current_path} #{pane_current_command}' 2>/dev/null)
assert_contains "恢复出的面板 cwd 正确" "$login_panes" "solo:1.1 $work/wd2"
assert_contains "白名单里的 nvim 被重新拉起" "$login_panes" "nvim"

# ── T6 注销/关机路径：先存档再收 server ─────────────────
step "T6 注销脚本：保存快照并关闭 server"
old_snapshot=$(readlink -f "$snapshot" 2>/dev/null || echo none)
if HOME="$work/home" XDG_CONFIG_HOME="$work/home/.config" "$stop_bin" >"$work/stop.log" 2>&1; then
  ok "tmux-persist-stop 执行成功"
else
  bad "tmux-persist-stop 执行失败：$(tail -2 "$work/stop.log" | tr '\n' ' ')"
fi
sleep 1
assert_eq "server 已被关闭" "no server running" "$(tmux_t list-sessions 2>&1 | head -1 | cut -d' ' -f1-3)"
new_snapshot=$(readlink -f "$snapshot" 2>/dev/null || echo none)
if [ "$new_snapshot" != "$old_snapshot" ] && [ -f "$snapshot" ]; then
  ok "注销时写下了新快照：$(basename "$new_snapshot")"
else
  bad "注销时未写下新快照（旧：$old_snapshot，现：$new_snapshot）"
fi
assert_contains "存档日志来自真实的 @resurrect-dir" "$(cat "$work/stop.log")" "保存会话快照到 $work/resurrect"

# ── 汇总 ─────────────────────────────────────────────────
printf '\n=== 汇总：%d 项通过，%d 项失败 ===\n' "$pass_count" "$fail"
[ "$fail" -eq 0 ]
