# 硬件扫描结果（源自 nixos-generate-config，已纳入版本控制）
# 修改本文件后通过 flake 重新部署：sudo nixos-rebuild switch --flake ~/Projects/nixos-config#desktop
{
  config,
  lib,
  pkgs,
  modulesPath,
  ...
}:

{
  imports = [
    (modulesPath + "/installer/scan/not-detected.nix")
  ];

  boot.initrd.availableKernelModules = [
    "xhci_pci"
    "ahci"
    "nvme"
    "usbhid"
    "usb_storage"
    "sd_mod"
  ];
  boot.initrd.kernelModules = [ ];
  boot.kernelModules = [
    "kvm-intel"
    "i2c-dev"
  ];
  boot.extraModulePackages = [ ];
  # 禁用声卡电源休眠:ALC1220 静音 10s 后会睡到 D3,唤醒时 DAC 渐入导致开头声音偏小
  boot.extraModprobeConfig = ''
    options snd-hda-intel power_save=0
  '';

  fileSystems."/" = {
    device = "/dev/disk/by-uuid/251f2194-cfde-4826-afcb-a7b117c9d4dd";
    fsType = "btrfs";
    # noatime：SSD 上 atime 更新纯属写放大；ssd 选项对 NVMe 由内核自动启用，无需显式指定
    options = [
      "subvol=@"
      "noatime"
    ];
  };

  fileSystems."/home" = {
    device = "/dev/disk/by-uuid/251f2194-cfde-4826-afcb-a7b117c9d4dd";
    fsType = "btrfs";
    options = [
      "subvol=@home"
      "noatime"
    ];
  };

  fileSystems."/nix" = {
    device = "/dev/disk/by-uuid/251f2194-cfde-4826-afcb-a7b117c9d4dd";
    fsType = "btrfs";
    options = [
      "subvol=@nix"
      "noatime"
    ];
  };

  fileSystems."/var" = {
    device = "/dev/disk/by-uuid/251f2194-cfde-4826-afcb-a7b117c9d4dd";
    fsType = "btrfs";
    options = [
      "subvol=@var"
      "noatime"
    ];
  };

  fileSystems."/var/log" = {
    device = "/dev/disk/by-uuid/251f2194-cfde-4826-afcb-a7b117c9d4dd";
    fsType = "btrfs";
    options = [
      "subvol=@log"
      "noatime"
    ];
  };

  fileSystems."/var/lib/docker" = {
    device = "/dev/disk/by-uuid/251f2194-cfde-4826-afcb-a7b117c9d4dd";
    fsType = "btrfs";
    options = [
      "subvol=@docker"
      "noatime"
    ];
  };

  fileSystems."/boot" = {
    device = "/dev/disk/by-uuid/41E5-09F9";
    fsType = "vfat";
    options = [
      "fmask=0022"
      "dmask=0022"
    ];
  };

  swapDevices = [ { device = "/dev/disk/by-uuid/3ab23e06-e327-4a55-80e3-1a85e0901274"; } ];

  # 压缩内存层：换页先走 zram（zstd，内存内压缩，无盘 I/O；默认上限 memoryPercent=50
  # ≈ 16 GB 未压缩等量，实际 RAM 占用约为其 1/3），上面的 NVMe 分区退为溢出兜底。
  # priority 必须高于分区的 -1，否则换页仍直写盘。
  zramSwap = {
    enable = true;
    priority = 100;
  };

  nixpkgs.hostPlatform = lib.mkDefault "x86_64-linux";
  hardware.cpu.intel.updateMicrocode = lib.mkDefault config.hardware.enableRedistributableFirmware;
}
