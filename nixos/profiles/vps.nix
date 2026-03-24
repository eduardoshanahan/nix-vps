{ modulesPath, ... }:
{
  imports = [
    "${modulesPath}/profiles/qemu-guest.nix"
  ];

  nixpkgs.hostPlatform = "x86_64-linux";

  # OVH VPS boots in legacy BIOS mode, not UEFI.
  # disko configures the grub device automatically from the EF02 partition.
  boot.loader.grub.enable = true;

  boot.initrd.availableKernelModules = [ "virtio_pci" "virtio_scsi" "ahci" "sd_mod" ];
}
