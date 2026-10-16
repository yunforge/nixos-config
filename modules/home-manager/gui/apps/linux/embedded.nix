# 嵌入式单片机开发环境（STM32 / ESP32 / AVR / RP2040）
# 覆盖：交叉编译工具链 + 烧录/调试工具 + PlatformIO 统一构建框架
# 归属 GUI 层：CubeMX 是图形化配置器，探针/串口也都在桌面场景下用，无图形环境的主机
# （server/wsl）不需要，故由 gui/apps 聚合而非 cli/dev。
{
  lib,
  config,
  pkgs,
  ...
}:
let
  cfg = config.mengw.gui.apps.embedded;
  guiCfg = config.mengw.gui;

  # CubeMX 固件包（HAL/LL/Cube 库，约 500MB）的下载位置。默认是 ~/STM32Cube/Repository，
  # 收拢到 ~/Apps（与 xwechat_files、Zotero 等应用数据同放一处）。
  cubemxRepository = "${config.home.homeDirectory}/Apps/STM32Cube/Repository/";
in
{
  options.mengw.gui.apps.embedded.enable = lib.mkOption {
    type = lib.types.bool;
    default = true;
    description = "启用嵌入式单片机开发环境（ARM/AVR 交叉工具链、烧录调试、PlatformIO）";
  };

  config = lib.mkIf (cfg.enable && guiCfg.enable) {
    home.packages =
      # === 通用（跨平台可用的烧录/调试协议与格式工具）===
      (with pkgs; [
        openocd # 通用片上调试器：ST-Link / J-Link / CMSIS-DAP，SWD/JTAG 下载与调试
        dfu-util # USB DFU 烧录（STM32 内置 DFU、RP2040/RP2350 等）
        srecord # 固件镜像格式转换（bin/hex/srec 互转、地址拼接）
        platformio # 统一嵌入式构建/依赖管理（pio），内置 Arduino/ESP-IDF/mbed/STM32Cube 等
      ])
      # === ARM Cortex-M/R 工具链（STM32 等）===
      ++ (with pkgs; [
        gcc-arm-embedded # ARM 预编译交叉工具链（arm-none-eabi-gcc/ld/gdb + newlib）
        pyocd # Python 调试烧录（CMSIS-DAP/DAPLink 等）
        probe-rs-tools # Rust 调试烧录（ST-Link/J-Link/CMSIS-DAP），配合 cargo-embed
      ])
      # === ESP32（乐鑫）===
      ++ (with pkgs; [
        esptool # ESP8266/ESP32 串口烧录（esptool.py）
        espflash # Rust 编写的 ESP 串口烧录器（串口监视用 espmonitor/espflash monitor）
      ])
      # === AVR / Arduino ===
      ++ (with pkgs; [
        # docSupport=true（Linux 默认）会为编文档拉整条 texlive→asymptote→pyqt5，
        # 而 PyQt5 5.15.10 在 Python 3.14 上无法编译（sip ABI v12 不匹配），导致构建失败。
        # 关闭文档构建：avrdude 本体功能不受影响。
        (avrdude.override { docSupport = false; }) # AVR 烧录器（Arduino Uno/Nano/Mega、ATtiny 等）
      ])
      # === RP2040 / RP2350（树莓派 Pico）===
      ++ (with pkgs; [
        picotool # Pico 固件工具（BOOTSEL 模式 flash / info / 固件校验）
      ])
      # === Linux 原生（nixpkgs 仅构建 Linux 版或不可用于其它平台，见下注释）===
      ++ lib.optionals pkgs.stdenv.hostPlatform.isLinux (
        with pkgs;
        [
          stlink # ST-Link 命令行烧录（st-flash / st-util），nixpkgs 仅构建 Linux 版
          # lsusb：查 USB 设备的 VID:PID。之所以要专门装，是因为直通探针/串口到
          # Windows 虚拟机时要填 vid:pid（见 winapps-usb 与 docs/winapps.md §10），
          # 而 NixOS 默认不带 usbutils。（usbutils 的 meta.platforms 仅 linux，
          # 故放这个 Linux 专属块而非上面的通用块。）
          usbutils
          # STM32 引脚/外设图形化配置（unfree，仅 x86_64-linux）。
          # HiDPI：AWT 的 uiScale 由全局 _JAVA_OPTIONS 按 mySystem.desktop.scale
          # 向上取整给出（modules/nixos/desktop/env.nix），无需单独包装。
          stm32cubemx
          android-tools
          # 原生 AVR 交叉编译工具链（avr-gcc 走 pkgsCross 从源码构建，仅 Linux 可用）
          pkgsCross.avr.buildPackages.gcc # avr-gcc 交叉编译器
          pkgsCross.avr.buildPackages.binutils # avr-objcopy/objdump/ld 等
          # 注意 1：不装 avr-gdb——它与 gcc-arm-embedded 自带同一批 GNU info 手册
          # （sframe-spec/ctf-spec/annotate 等），buildEnv 合并 profile 时路径冲突。
          # avr 调试可走 PlatformIO 或单机 devShell；需要 gdb 时在该 shell 里单独引入。
          # 注意 2：不带 avr-libc——它的 meta.platforms = ["avr-none"]，属于 AVR 目标运行库，
          # 不能被装进 x86_64 主机 profile。裸机 AVR（无 libc）avr-gcc 可直接用；
          # 需要 libc 的 AVR 工程请走 PlatformIO（已装）或在该工程的 devShell 里以
          # buildInputs 引用 pkgsCross.avr.avrlibc。
        ]
      );

    # === 固件仓库路径锚定 ===
    # 该路径记在 ~/.stm32cubemx/plugins/updater/updater.ini 的 [Path] 段，但同一 ini 还
    # 混着更新时间戳/窗口尺寸等可变状态，无法整体托管，故只在每次切换时钉住这一行。
    # 数据本身不搬运——首次迁移需手动 mv（见 docs/quirks.md），之后
    # CubeMX 下载新固件包即直接落到 cubemxRepository。
    home.activation.stm32cubemxRepository = lib.hm.dag.entryAfter [ "writeBoundary" ] (
      lib.optionalString pkgs.stdenv.hostPlatform.isLinux ''
        ini="${config.home.homeDirectory}/.stm32cubemx/plugins/updater/updater.ini"
        if [ ! -f "$ini" ]; then
          verboseEcho "CubeMX 尚未运行过（$ini 不存在），跳过固件仓库路径锚定"
        else
          $DRY_RUN_CMD ${pkgs.coreutils}/bin/mkdir -p "${cubemxRepository}"
          current=$(${pkgs.gnused}/bin/sed -n 's|^RepositoryPath=||p' "$ini")
          if [ "$current" = "${cubemxRepository}" ]; then
            verboseEcho "CubeMX 固件仓库路径已正确：${cubemxRepository}"
          else
            verboseEcho "CubeMX 固件仓库路径漂移（$current → ${cubemxRepository}），已修正"
            $DRY_RUN_CMD ${pkgs.gnused}/bin/sed -i "s|^RepositoryPath=.*|RepositoryPath=${cubemxRepository}|" "$ini"
          fi
        fi
      ''
    );
  };
}
