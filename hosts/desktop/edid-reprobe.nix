# 显示器 EDID 首读失败自愈：给连接器注入本屏完整 EDID，避免冷上电后分辨率塌陷
#
# 现象：4K 屏长时间断电再上电，桌面内容变得巨大（2026-09-15/17/18/21/25、09-26 多次
# 复现）。此时 niri 日志里连接器身份是 "Nvidia 0x0000 Unknown"，模式列表只剩 640x480，
# 叠加 outputs.kdl 的 scale 1.5 → 逻辑 426x320，只能重启或重插线恢复。
#
# 根因（nvidia-drm 源码 + 内核 DRM 源码 + 2026-09-26 实测）：
#   1. 该屏冷上电时序是"DP 接收端先起来（1~3s 内就拉高 HPD）、scaler/EDID 后起来"。
#      NVIDIA 驱动在 HPD 边沿立刻取一次 EDID，拿到的是合成 stub（mfg "NVD"、product
#      0x0000、无详细时序、校验和有效），并连同显示对象一起缓存在 RM 里。
#   2. RM 的显示对象只在新 HPD 边沿或驱动重新加载时重建。`echo detect > status` 只做
#      free(nv_connector->edid) + 再问一次 RM，而后者拿的是 pDetectParams->handle =
#      nv_encoder->hDisplay 指向的既有显示对象，回的还是同一份 stub。2026-09-26 实测：
#      detect 每 2s 打满 10 分钟、外加两轮 force=off（enabled 真的变 disabled、链路真断）
#      + detect，模式列表始终是 640x480；同一时间 ddcutil 直读 I2C 已能读出本屏 EDID。
#      旧版自愈（detect 轮询 + off/detect 重训）因此不可能生效——不是"等得不够久"。
#   3. 该屏 EDID 本身也不可靠：同一台显示器、正在跑 4K150 的同时，i2c 直读它的块 2 却
#      回一份 base block（最高 4K60、没有 DisplayID）。也就是说 EDID 内容不一定代表面板
#      此刻的能力，只是固件选错了 bank，不能拿"直读到什么"当作面板能否上 4K150 的依据。
#   4. 试过让显示器自己重初始化来产生新 HPD 边沿：本屏拒绝 VCP D6=0x04（DDCRC_VERIFY，
#      HPD 从不撤销），硬关机 0x05 又会让 DDC 一起失效、只能人工按电源键；源侧 force=off
#      同样不会撤销 sink 的 HPD。这条路不适合做成自动自愈。
#
# 修复思路：既然唯一可靠的是"在内核侧给连接器一份正确 EDID"，就用 DRM 自带的 EDID override
# （连接器 debugfs 的 edid_override，写二进制 EDID，写 "reset" 撤销）：
#   - 内核 7.2 起 drm_helper_probe_single_connector_modes() 不再因为 override 存在就跳过
#     detect，所以连接器状态仍由 RM 按真实 HPD 汇报——显示器断电/拔线照样能感知，不会
#     变成 drm.edid_firmware 那种"连接器永远 connected、关电也不复位"的黑屏。
#   - nvidia-drm 每次 detect 都会调 drm_edid_override_connector_update()，把 override 塞进
#     NvKmsKapiDynamicDisplayParams（overrideEdid=NV_TRUE）交给 RM，于是 RM 的模式列表就
#     来自我们给的 EDID，niri 能重新选回 3840x2160@150。
#   - 只在检出 stub、且显示器 MCU 已就绪（DDC 能应答）时才注入，避免冷启动早期把 4K 模式
#     塞给还没起来的面板；连接器一旦断开就把 override 复位，下次上电仍从真实 HPD 判断。
#
# hosts/desktop/edid/icd-gx288ur.bin = 本屏健康时的完整 EDID（384 字节，块 2 是 DisplayID，
# 含 3840x2160@150 的 Type I 时序）。显示器换机或换固件后需要重新生成：
#   cat /sys/class/drm/card1-DP-3/edid > hosts/desktop/edid/icd-gx288ur.bin   # 在 4K150 正常时
#
# 已排除：drm.edid_firmware（开机即生效 → 冷启动早期就把 4K 模式塞给未就绪面板，且 override
# 不再复位 → 黑屏）、video=DP-3:...（NVIDIA 拒绝 user-defined 模式 → 黑屏）。
{
  pkgs,
  ...
}:
let
  # ICD 4K 屏所在连接器（2026-10-26 新增华为 SSN-24 占用 DP-2 后，本屏从 DP-2 挪到 DP-3）
  connector = "card1-DP-3";
  card = "card1";
  expectedMode = "3840x2160";
  # 换屏保护：ddcutil 报的 mfg:model 必须与 EDID 文件对得上，否则不注入
  expectedPanel = "ICD:ICD GX288UR";
  panelEdid = ./edid/icd-gx288ur.bin;
  # 冷上电后 scaler/DDC 要几十秒到几分钟才就绪：2026-09-26 07:17 出 stub，07:19 DDC
  # 已能应答（约 2 分钟），留 10 分钟余量
  readyTimeout = 600;

  reprobe = pkgs.writeShellScript "edid-reprobe" ''
    set -u

    sys=/sys/class/drm/${connector}
    expected=${expectedMode}
    expected_panel="${expectedPanel}"
    panel_edid=${panelEdid}
    ddc=${pkgs.ddcutil}/bin/ddcutil
    date=${pkgs.coreutils}/bin/date
    sleep=${pkgs.coreutils}/bin/sleep
    cat=${pkgs.coreutils}/bin/cat
    od=${pkgs.coreutils}/bin/od
    head=${pkgs.coreutils}/bin/head
    tr=${pkgs.coreutils}/bin/tr
    find=${pkgs.findutils}/bin/find
    grep=${pkgs.gnugrep}/bin/grep

    log() {
      printf '[%s] [edid-reprobe] %s\n' "$($date -Is)" "$*" >&2
    }

    connector_status() {
      $cat "$sys/status" 2>/dev/null || echo unknown
    }

    has_expected_mode() {
      $grep -qx "$expected" "$sys/modes" 2>/dev/null
    }

    # NVIDIA 合成 stub 的签名：manufacturer "NVD"(0x3ac4) + product 0x0000；
    # 本屏真实 EDID 是 ICD(0x2464)/0x753c。
    is_stub_edid() {
      [ "$($od -An -j8 -N4 -tx1 "$sys/edid" 2>/dev/null | $tr -d ' \n')" = "3ac40000" ]
    }

    # 连接器 debugfs 目录用的是 connector->name（本机 DP-3），不是 sysfs 的 card1-DP-3；
    # 实测完整路径是 /sys/kernel/debug/dri/0000:01:00.0/DP-3/edid_override
    # （中间那层是 PCI 名，不是 minor 号），故这里按名字找而不是写死路径。
    find_override() {
      $find /sys/kernel/debug/dri -maxdepth 3 -type f -name edid_override 2>/dev/null |
        $grep -E '/DP-3/edid_override$' | $head -1
    }

    # niri（经 smithay 的 udev backend）只跟踪 sysname 匹配 card[0-9] 的显卡设备本身，
    # 戳连接器子设备会被 change 事件过滤丢弃，所以通知目标是 card1。
    notify_compositor() {
      ${pkgs.systemd}/bin/udevadm trigger \
        --subsystem-match=drm --sysname-match=${card} -c change
    }

    override=$(find_override)

    # 显示器断电/拔线：撤销 override，让状态重新完全由 RM 的真实 HPD 决定，
    # 免得下次上电时面板还没就绪就被塞进 4K 模式。
    if [ "$(connector_status)" != connected ]; then
      if [ -n "$override" ] && [ -s "$override" ]; then
        printf reset > "$override" && log "连接器已断开，撤销 EDID override"
      fi
      exit 0
    fi

    # 规则挂在 card1 上，正常热插拔、自愈后自己触发的 change 事件都会走到这里，
    # 健康路径必须静默退出。
    has_expected_mode && exit 0

    if ! is_stub_edid; then
      log "${connector} 缺 $expected，但 EDID 不是 NVIDIA stub，跳过"
      exit 0
    fi

    [ -n "$override" ] || {
      log "找不到 ${connector} 的 debugfs edid_override（debugfs 未挂载？），无法注入"
      exit 1
    }
    [ -s "$panel_edid" ] || {
      log "面板 EDID 文件 $panel_edid 为空，无法注入"
      exit 1
    }

    log "${connector} 已连接但 EDID 是 NVIDIA 合成 stub（无 $expected），等显示器就绪后注入真实 EDID"

    # 用 detect 的结果做"面板已就绪 + 身份匹配"的判据：detect 能按身份列出
    # ICD，本身就说明该屏 DDC 已成功读出 EDID（身份串来自 EDID），无需再探
    # VCP——多显示器下 getvcp 不带 --bus 只摸默认 display，而 --bus 要抓
    # detect 报的瞬时总线号，本机 NVIDIA 的 i2c 总线号在两次探测间会漂移，有竞态。
    deadline=$(($($date +%s) + ${toString readyTimeout}))
    rounds=0
    while :; do
      [ "$(connector_status)" = connected ] || {
        log "等待显示器就绪期间断开，放弃本次修复"
        exit 0
      }

      if $ddc detect --brief 2>/dev/null | $grep -qF "$expected_panel"; then
        break
      fi

      if [ "$($date +%s)" -ge "$deadline" ]; then
        log "${toString readyTimeout}s 内显示器 DDC 未就绪（scaler 可能还在启动），放弃本次修复"
        exit 1
      fi

      # 冷上电后要等几十秒到几分钟，每分钟留一条进度，方便下次回看等了多久
      rounds=$((rounds + 1))
      if [ $((rounds % 12)) -eq 0 ]; then
        log "已等待 $((rounds * 5))s，显示器 DDC 仍未就绪"
      fi
      $sleep 5
    done

    log "显示器已就绪，注入面板完整 EDID（含 3840x2160@150 的 DisplayID 块）"
    if ! $cat "$panel_edid" > "$override"; then
      log "写入 edid_override 失败"
      exit 1
    fi

    # override 生效还需要一次 probe 把模式列表刷出来，再通知合成器重选模式
    echo detect > "$sys/status" 2>/dev/null || true
    notify_compositor

    waited=0
    while [ "$waited" -lt 10 ]; do
      waited=$((waited + 1))
      if has_expected_mode; then
        log "注入后已恢复 $expected"
        exit 0
      fi
      $sleep 1
    done

    log "注入后仍未出现 $expected（可能需要物理重插 DP 线或重启）"
    exit 1
  '';
in
{
  # 显示器上电会触发 card1 的 change 事件（DRM 的 hotplug uevent 一律发在显卡节点，
  # 连接器子设备收不到）。--no-block 避免阻塞 udev 事件处理；服务自身幂等。
  services.udev.extraRules = ''
    SUBSYSTEM=="drm", ACTION=="change", KERNEL=="${card}", RUN+="${pkgs.systemd}/bin/systemctl --no-block start edid-reprobe.service"
  '';

  systemd.services.edid-reprobe = {
    description = "检出 NVIDIA stub EDID 时注入面板真实 EDID，修复冷启动后分辨率塌陷";
    serviceConfig = {
      Type = "oneshot";
      # oneshot 默认无启动超时；脚本自带上限（10 分钟等就绪），这里再兜一层
      TimeoutStartSec = 900;
      ExecStart = "${reprobe}";
    };
  };
}
