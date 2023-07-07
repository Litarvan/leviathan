{ lib, modulesPath, ... }:

{
  imports = [
    (modulesPath + "/profiles/qemu-guest.nix")

    ./nginx.nix
    ./wireguard.nix
  ];

  boot = {
    initrd.availableKernelModules = [ "ata_piix" "uhci_hcd" "xen_blkfront" ];
    kernelModules = [ "nvme" ];

    loader.grub = {
      efiSupport = true;
      efiInstallAsRemovable = true;
      device = "nodev";
    };
  };

  networking.hostName = "alligator";

  nix.settings.max-jobs = lib.mkDefault 4;

  fileSystems = {
    "/" = {
      device = "/dev/sda1";
      fsType = "ext4";
    };

    "/boot" = {
      device = "/dev/disk/by-uuid/7645-EEF4";
      fsType = "vfat";
    };

    "/boot.real" = {
      device = "/dev/disk/by-uuid/FC03-B17A";
      fsType = "vfat";
    };
  };

  system.stateVersion = "22.11";
  home-manager.users.litarvan.home.stateVersion = "23.05"; # Installed after updating to 23.05
}
