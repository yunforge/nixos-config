# QEMU/KVM + libvirtd 虚拟化模块
#
# 消费者：virt-manager/virt-viewer 手动使用，以及 WinApps（Windows 应用独立窗口接入，
# 见 modules/home-manager/gui/desktop/linux/winapps.nix）。Windows 11 需要 swtpm（TPM 2.0）与
# nixpkgs 默认携带的 OVMF（Secure Boot），二者均已在此模块就位。
{
  lib,
  config,
  pkgs,
  ...
}:
let
  cfg = config.mySystem.virtualization;
in
{
  config = lib.mkIf cfg.enable {
    programs.virt-manager.enable = true;

    environment.systemPackages = with pkgs; [
      virt-viewer
      # 主机目录共享给 Windows 客户机（virtiofs）的守护进程
      virtiofsd
      # 虚拟机装机介质（挂 virt-manager 的 CDROM 设备）：
      #   /run/current-system/sw/share/windows-vm-media/windows-vm-media.iso
      # 上游 virtio-win ISO + WinApps oem 注册脚本，经 overlays/default.nix
      # 注入（winappsRev 按 flake.lock 固定，升级输入后哈希失配会显式报错）。
      # 文件本身不变时该派生不重建；日后不再新建虚拟机可以从这里删掉省 ~840MB
      windows-vm-media
    ];

    virtualisation.libvirtd = {
      enable = true;
      qemu = {
        package = pkgs.qemu_kvm;
        swtpm.enable = true;
        # 主机目录共享给 Windows 客户机（virtiofs）需要 vhost-user 后端可执行文件；
        # 否则 virsh/virt-manager 建 virtiofs 共享时报 "virtiofsd not found"
        vhostUserPackages = [ pkgs.virtiofsd ];
      };
    };

    virtualisation.spiceUSBRedirection.enable = true;

    networking.firewall.trustedInterfaces = [ "virbr0" ];

    boot.extraModprobeConfig = ''
      options kvm_intel nested=1
    '';
  };
}
