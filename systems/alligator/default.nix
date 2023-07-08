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

  networking.hostName = "alligator";

  # This can be deleted after the instance initial setup.
  # The file should contain a single line with the bcrypt hashed password.
  users.users.litarvan.passwordFile = "/data/secrets/litarvan-password";

  nix.settings.max-jobs = lib.mkDefault 4;

  system.stateVersion = "22.11";
  home-manager.users.litarvan.home.stateVersion = "23.05"; # Installed after updating to 23.05
}
