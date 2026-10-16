# WinApps：把 Windows 虚拟机里的应用以独立窗口接入桌面（FreeRDP RemoteApp）
#
# 本模块只负责「接入层」：包、winapps.conf、RDP 密码取值方式。
# 虚拟机本身必须人工建一次——Windows 安装过程无法用 Nix 表达：
#   1. virt-manager 新建虚拟机，名称须与 winapps.vmName 一致；机器类型 q35，
#      固件 UEFI(OVMF, secure boot) + TPM 2.0(crb, swtpm) + virtio 磁盘/网卡，
#      安装 Windows 11 Pro（RemoteApp 需要 Pro/Enterprise，Home 版不行）；
#   2. 挂本仓库打包的装机介质（mySystem.virtualization 的 windows-vm-media.iso）：
#      装系统时用「加载驱动程序」指向盘内 amd64\w11，装完运行盘根目录
#      virtio-win-guest-tools.exe，再以管理员运行 oem\install.bat（导入 RemoteApp 注册表）。
#   3. 首次执行 `winapps-setup --user`：查询 Windows 已装程序并生成各应用的
#      .desktop 与启动脚本。仅此一步是命令式的，其余均由本模块托管。
#
# 硬件探针（ST-Link/J-Link/CMSIS-DAP）不进 RDP，而是以 libvirt <hostdev> 直通给
# 客户机：日常用本模块提供的 `winapps-usb attach <vid:pid>`（热插拔，用完 detach 交还
# Linux）；想要开机即直通就用 virt-manager → Add Hardware → USB Host Device
# （代价：设备总被 VM 占着）。同一探针无法同时给 Linux 与 Windows，详见 docs/winapps.md §10。
{
  lib,
  config,
  pkgs,
  osConfig,
  inputs,
  ...
}:
let
  cfg = config.mengw.gui.winapps;
  desktopCfg = config.mengw.desktop;

  winapps = inputs.winapps.packages.${pkgs.stdenv.hostPlatform.system};

  homeDir = config.home.homeDirectory;

  # RDP 密码不能落进 nix store（store 路径全局可读），改由 FREERDP_ASKPASS
  # 从非托管的 0600 文件读取；该文件需手动创建一次（见下方 activation 提示）。
  rdpPassFile = "${homeDir}/.config/winapps/rdp-pass";

  # WinApps 只接受 100/140/180 三档，按桌面声明的缩放取最近值：
  # 1.5 倍屏 → 140，2 倍及以上 → 180，其余 → 100。可用 cfg.rdpScale 覆盖。
  desktopScale = osConfig.mySystem.desktop.scale;
  derivedScale =
    if desktopScale >= 1.7 then
      "180"
    else if desktopScale >= 1.3 then
      "140"
    else
      "100";
  rdpScale = if cfg.rdpScale != null then cfg.rdpScale else derivedScale;

  extraDriveFlags = lib.concatMapStrings (d: " /drive:${d.name},${d.path}") cfg.extraDrives;

  # USB 直通热插拔封装。
  #
  # 为什么需要它：WinApps 的 RDP 通道只重定向剪贴板/音频/磁盘，**不传 USB**。
  # 单片机探针与 USB-UART 只能走 libvirt 的 USB hostdev 直通（原生 USB 语义）。
  # 而 hostdev 是**独占**的：QEMU 用 libusb 抢占接口（内核驱动被解绑、接口改挂到
  # usbfs 伪驱动），于是 /dev/ttyUSB0 消失，st-flash / openocd / tio 全部打不开。
  # 注意设备**仍会出现在 lsusb 里**（只是没人能用它），别被这点误导。
  # 所以这里提供热插拔（virsh --live）而非把设备永久钉进域 XML：默认「谁用谁拿」，
  # 用完 detach 还给 Linux。
  winappsUsb = pkgs.writeShellScriptBin "winapps-usb" ''
    set -u

    readonly VM="${cfg.vmName}"
    export LIBVIRT_DEFAULT_URI="qemu:///system"

    # virsh 取系统 PATH 里的那份（与 libvirtd 同源）；不写死 store 路径，
    # 以免 HM 里的 libvirt 与系统守护进程版本不一致。
    command -v virsh >/dev/null 2>&1 || {
      printf '[DEBUG] winapps-usb: PATH 里找不到 virsh（libvirt 客户端未安装？）\n' >&2
      exit 1
    }

    # 设备直通期间宿主机看不到它，两份清单来源不同，必须分开呈现
    readonly XML="''${XDG_RUNTIME_DIR:-/tmp}/winapps-usb-hostdev.xml"
    trap 'rm -f -- "$XML"' EXIT

    die() { printf '[DEBUG] winapps-usb: %s\n' "$*" >&2; exit 1; }

    usage() {
      cat >&2 <<'USAGE'
    用法：
      winapps-usb                   列出「已直通给 VM」与「宿主机可见」的 USB 设备
      winapps-usb attach <vid:pid>  热插设备给 VM（仅本次运行；Linux 侧就此失去该设备）
      winapps-usb detach <vid:pid>  把设备交还 Linux
    设备 ID 见 winapps-usb 输出，形如 0483:3748。
    USAGE
    }

    # 宿主可见设备：读 sysfs，不依赖未安装的 usbutils；跳过根控制器与 hub
    host_devices() {
      local d idv idp name cls
      for d in /sys/bus/usb/devices/*/; do
        [ -r "$d/idVendor" ] || continue
        idv=$(cat "$d/idVendor"); idp=$(cat "$d/idProduct")
        [ "$idv" = "1d6b" ] && continue
        cls=$(cat "$d/bDeviceClass" 2>/dev/null)
        [ "$cls" = "09" ] && continue
        name=$(cat "$d/product" 2>/dev/null || echo "?")
        printf '%s:%s\t%s\n' "$idv" "$idp" "$name"
      done | sort -u
    }

    # 已直通设备：此刻宿主机完全看不到，只能从域 XML 反查
    vm_devices() {
      virsh dumpxml "$VM" 2>/dev/null \
        | tr -d ' \n' | tr 'A-Z' 'a-z' \
        | grep -o "<vendorid='0x[0-9a-f]*'/><productid='0x[0-9a-f]*'/>" \
        | sed -E "s|<vendorid='0x([0-9a-f]*)'/><productid='0x([0-9a-f]*)'/>|\1:\2|"
    }

    # 解析并校验 vid:pid，结果放 VID/PID（小写）
    VID=""; PID=""
    parse_id() {
      local id="''${1:-}"
      case "$id" in
        *:*) VID="''${id%%:*}"; PID="''${id##*:}" ;;
        *)   die "设备 ID 要写成 vid:pid（如 0483:3748），当前是 '$id'" ;;
      esac
      [[ "$VID" =~ ^[0-9a-fA-F]{4}$ ]] || die "vendor ID 必须是 4 位十六进制，当前 '$VID'"
      [[ "$PID" =~ ^[0-9a-fA-F]{4}$ ]] || die "product ID 必须是 4 位十六进制，当前 '$PID'"
      VID="''${VID,,}"; PID="''${PID,,}"
    }

    # virsh 只接受文件路径，故落一份 XML；同 vid:pid 不论主机地址都匹配
    write_xml() {
      cat > "$XML" <<XML_EOF
    <hostdev mode='subsystem' type='usb' managed='yes'>
      <source>
        <vendor id='0x$VID'/>
        <product id='0x$PID'/>
      </source>
    </hostdev>
    XML_EOF
    }

    case "''${1:-list}" in
      list)
        vm=$(vm_devices)
        printf '== 已直通给 %s ==\n' "$VM"
        printf '   （内核驱动已解绑、接口改挂 usbfs：/dev 节点消失，st-flash/tio 打不开；lsusb 仍能列出）\n'
        if [ -n "$vm" ]; then printf '%s\n' "$vm" | sed 's/^/  /'; else printf '  （无）\n'; fi

        printf '\n== 宿主机可见且未直通 ==\n'
        shown=0
        while IFS=$'\t' read -r id name; do
          [ -n "$id" ] || continue
          # 已直通的归上一节，否则同一设备会在两节里各出现一次（sysfs 并未移除它）
          if [ -n "$vm" ] && printf '%s\n' "$vm" | grep -qx "$id"; then continue; fi
          printf '  %s\t%s\n' "$id" "$name"; shown=1
        done < <(host_devices)
        [ "$shown" = 1 ] || printf '  （无）\n'
        ;;
      attach)
        parse_id "''${2:-}"
        vm_devices | grep -qx "$VID:$PID" \
          && die "$VID:$PID 已经在 $VM 里了，无需重复 attach"
        host_devices | cut -f1 | grep -qx "$VID:$PID" \
          || die "宿主机看不到 $VID:$PID：要么没插稳，要么已被 $VM 直通（先跑一次 winapps-usb 看现状）"
        write_xml
        virsh attach-device "$VM" "$XML" --live \
          || die "attach $VID:$PID 失败，原因见上方 virsh 输出"
        printf '[DEBUG] winapps-usb: %s:%s 已热插给 %s；宿主侧驱动被解绑（/dev 节点消失，lsusb 仍在）\n' "$VID" "$PID" "$VM" >&2
        printf 'Windows 设备管理器应出现新设备；ST-Link 还需装 Windows 侧驱动（STSW-LINK009），\n否则会先显示为“其他设备”。用完执 winapps-usb detach %s:%s 交还 Linux。\n' "$VID" "$PID"
        ;;
      detach)
        parse_id "''${2:-}"
        vm_devices | grep -qx "$VID:$PID" \
          || die "$VID:$PID 不在 $VM 里，无需 detach（winapps-usb 看现状）"
        write_xml
        virsh detach-device "$VM" "$XML" --live \
          || die "detach $VID:$PID 失败，原因见上方 virsh 输出"
        printf '[DEBUG] winapps-usb: %s:%s 已交还 Linux\n' "$VID" "$PID" >&2
        ;;
      help|-h|--help)
        usage
        ;;
      *)
        usage
        die "未知子命令 '$1'"
        ;;
    esac
  '';
in
{
  options.mengw.gui.winapps = {
    enable = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "WinApps（Windows 应用以独立窗口接入桌面）";
    };

    vmName = lib.mkOption {
      type = lib.types.str;
      default = "RDPWindows";
      description = "libvirt 中的 Windows 虚拟机名，须与 `virsh list --all` 一致";
    };

    windowsUser = lib.mkOption {
      type = lib.types.str;
      default = "mengw";
      description = "Windows 登录用户名（RDP 凭据）";
    };

    # null 表示按 mySystem.desktop.scale 自动派生
    rdpScale = lib.mkOption {
      type = lib.types.nullOr (
        lib.types.enum [
          "100"
          "140"
          "180"
        ]
      );
      default = null;
      description = "RDP 缩放档位（FreeRDP 只支持 100/140/180 三档）";
    };

    extraDrives = lib.mkOption {
      type = lib.types.listOf (
        lib.types.submodule {
          options = {
            name = lib.mkOption {
              type = lib.types.str;
              description = "Windows 侧 \\\\tsclient\\<name> 的共享名";
            };
            path = lib.mkOption {
              type = lib.types.str;
              description = "暴露给 Windows 的主机目录绝对路径";
            };
          };
        }
      );
      default = [
        {
          name = "proj";
          path = "${homeDir}/Projects";
        }
      ];
      description = "额外以 RDP 磁盘重定向暴露给 Windows 的目录";
    };
  };

  config = lib.mkIf (cfg.enable && desktopCfg.enable) {
    # winapps 自己包装了 freerdp（仅限其脚本可见）；这里额外装一份到用户 PATH，
    # 供手动全屏 RDP 会话（xfreerdp / wlfreerdp）与排错用（xfreerdp +auth-only 验凭据、
    # 单跑一次 RemoteApp 会话）。不会改变 winapps 的自动探测结果：包装器把同一份 freerdp
    # 前置到 PATH，仍取 sdl-freerdp。
    home.packages = [
      winapps.winapps
      winapps.winapps-launcher
      pkgs.freerdp
      winappsUsb
    ];

    # 与 virt-manager/virsh 统一 URI，避免默认落到 qemu:///session 找不到域
    home.sessionVariables.LIBVIRT_DEFAULT_URI = "qemu:///system";

    home.file.".local/bin/winapps-askpass" = {
      executable = true;
      text = ''
        #!/usr/bin/env bash
        # WinApps 把 RDP_ASKPASS 导出为 FREERDP_ASKPASS，FreeRDP 取本脚本 stdout 作为密码
        exec ${pkgs.coreutils}/bin/cat "${rdpPassFile}"
      '';
    };

    xdg.configFile."winapps/winapps.conf".text = ''
      # 由 home-manager 托管（modules/home-manager/gui/winapps.nix），请改配置而非本文件
      RDP_USER="${cfg.windowsUser}"
      RDP_ASKPASS="${homeDir}/.local/bin/winapps-askpass"
      RDP_DOMAIN=""
      WAFLAVOR="libvirt"
      VM_NAME="${cfg.vmName}"
      RDP_SCALE="${rdpScale}"
      # +home-drive → Windows 侧 \\tsclient\home；/drive: → 额外共享盘
      RDP_FLAGS="/cert:tofu /sound /microphone +home-drive${extraDriveFlags}"
      DEBUG="true"
    '';

    # 密码文件是唯一不托管的输入，缺失时明确提示而非静默失败
    home.activation.winappsRdpPasswordCheck = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
      if [ ! -f "${rdpPassFile}" ]; then
        warnEcho "WinApps 尚未设置 Windows 密码，请执行：printf '%s' '你的密码' > ${rdpPassFile} && chmod 600 ${rdpPassFile}"
      fi
    '';
  };
}
