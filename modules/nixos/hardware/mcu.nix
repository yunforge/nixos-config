# 单片机烧录/调试器 USB 访问（udev 规则）
# 直接授权到 users 组（mengw 主组）并设 MODE=0660，无需加入 dialout 组或以 sudo 运行。
# 曾用 uaccess 标签方案（logind 按活跃会话自动下发 ACL），实测不生效：节点保持 root:root 664、
# 无 ACL 条目，st-info/openocd 用 libusb 直连 /dev/bus/usb 时写权限被拒（access error），
# 故改为确定性 group/mode 授权（工具见 modules/home-manager/gui/apps/linux/embedded.nix）。
{ lib, config, ... }:
let
  cfg = config.mySystem.hardware;
in
{
  options.mySystem.hardware.mcu.enable = lib.mkEnableOption "单片机烧录/调试器 USB 设备访问";

  config = lib.mkIf (cfg.enable && cfg.mcu.enable) {
    services.udev.extraRules = ''
      # === 烧录/调试器 ===
      # ST-Link / STM32 DFU（ST 自家 debug probe 与内置 DFU 下载器）
      SUBSYSTEM=="usb", ATTR{idVendor}=="0483", ATTR{idProduct}=="3748", GROUP="users", MODE="0660"
      SUBSYSTEM=="usb", ATTR{idVendor}=="0483", ATTR{idProduct}=="374b", GROUP="users", MODE="0660"
      SUBSYSTEM=="usb", ATTR{idVendor}=="0483", ATTR{idProduct}=="374d", GROUP="users", MODE="0660"
      SUBSYSTEM=="usb", ATTR{idVendor}=="0483", ATTR{idProduct}=="374e", GROUP="users", MODE="0660"
      SUBSYSTEM=="usb", ATTR{idVendor}=="0483", ATTR{idProduct}=="3752", GROUP="users", MODE="0660"
      SUBSYSTEM=="usb", ATTR{idVendor}=="0483", ATTR{idProduct}=="3753", GROUP="users", MODE="0660"
      SUBSYSTEM=="usb", ATTR{idVendor}=="0483", ATTR{idProduct}=="3754", GROUP="users", MODE="0660"
      SUBSYSTEM=="usb", ATTR{idVendor}=="0483", ATTR{idProduct}=="df11", GROUP="users", MODE="0660"

      # SEGGER J-Link（0366/1366 全系为专用调试器，放开 vendor 即可）
      SUBSYSTEM=="usb", ATTR{idVendor}=="1366", GROUP="users", MODE="0660"

      # CMSIS-DAP / DAPLink / mbed（0d28 为 ARM 官方 CMSIS-DAP 实现厂商）
      SUBSYSTEM=="usb", ATTR{idVendor}=="0d28", GROUP="users", MODE="0660"

      # Black Magic Probe（1d50 为 OpenMoko/自由硬件厂商）
      SUBSYSTEM=="usb", ATTR{idVendor}=="1d50", ATTR{idProduct}=="6015", GROUP="users", MODE="0660"
      SUBSYSTEM=="usb", ATTR{idVendor}=="1d50", ATTR{idProduct}=="6017", GROUP="users", MODE="0660"
      SUBSYSTEM=="usb", ATTR{idVendor}=="1d50", ATTR{idProduct}=="6018", GROUP="users", MODE="0660"

      # Raspberry Pi Debug Probe / RP2040/RP2350 原生 USB 下载（2e8a 为树莓派官方）
      SUBSYSTEM=="usb", ATTR{idVendor}=="2e8a", GROUP="users", MODE="0660"

      # === USB-UART 桥（ESP32/STM32 等串口下载与串口监视用）===
      # 沁恒 WCH：CH340/CH341/CH343/CH9102
      SUBSYSTEM=="usb", ATTR{idVendor}=="1a86", GROUP="users", MODE="0660"
      # 慧荣/Silicon Labs：CP210x
      SUBSYSTEM=="usb", ATTR{idVendor}=="10c4", GROUP="users", MODE="0660"
      # FTDI：FT232/FT2232 等 USB-UART/JTAG 桥
      SUBSYSTEM=="usb", ATTR{idVendor}=="0403", GROUP="users", MODE="0660"
    '';
  };
}
