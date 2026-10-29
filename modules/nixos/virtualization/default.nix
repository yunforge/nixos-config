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

  # virgl 3D 加速下 QEMU 要在宿主 GPU 上建 EGL 上下文，除 libvirt 为 <gl>
  # 动态补的 /dev/dri/renderD* 外还需要 NVIDIA 的字符设备；缺了会 EGL_NOT_INITIALIZED。
  # 注意：本机 cgroup v2 上 libvirt 并未挂 device BPF（scope 的 cgroup.controllers
  # 里没有 device），这份 ACL 实际未被强制执行，属于兜底；SPICE 3D 黑屏的真因见
  # docs/quirks.md「SPICE 3D 在本机 NVIDIA 专有驱动上必然黑屏」。
  nvidiaDeviceAcl = lib.optionalString config.mySystem.hardware.nvidia.enable ''
    , "/dev/nvidiactl", "/dev/nvidia0", "/dev/nvidia-modeset",
      "/dev/nvidia-uvm", "/dev/nvidia-uvm-tools"
  '';
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

        verbatimConfig = ''
          namespaces = []
          cgroup_device_acl = [
            "/dev/null", "/dev/full", "/dev/zero",
            "/dev/random", "/dev/urandom",
            "/dev/ptmx", "/dev/kvm", "/dev/net/tun"${nvidiaDeviceAcl}
          ]
        '';
      };
    };

    virtualisation.spiceUSBRedirection.enable = true;

    networking.firewall.trustedInterfaces = [ "virbr0" ];

    boot.extraModprobeConfig = ''
      options kvm_intel nested=1
    '';
  };
}
