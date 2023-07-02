{ lib, ... }:

{
  boot = {
    initrd.availableKernelModules = [ "xhci_pci" "ehci_pci" "ahci" "usbhid" "sd_mod" ];
    kernelModules = [ "kvm-intel" ];

    postBootCommands = ''
      mkdir -p /data/{nvme1,hdd1,usb1}
    '';
  };

  netboot.enable = true;

  networking = {
    hostName = "leviathan-alpha";
    interfaces.eth0.useDHCP = true;
  };

  services.xserver.videoDrivers = [ "nvidia" ];
  hardware.opengl = {
    enable = true;
    driSupport32Bit = true;
  };
  hardware.nvidia.modesetting.enable = true;

  nix.settings.max-jobs = lib.mkDefault 4;
  powerManagement.cpuFreqGovernor = lib.mkDefault "powersave";

  fileSystems = {
    "/data/nvme1" = {
      label = "lvth_data_nvme1";
      fsType = "ext4";
    };

    "/data/hdd1" = {
      label = "lvth_data_hdd1";
      fsType = "ext4";
    };

    "/data/usb1" = {
      label = "LVTH_ALPHA";
      fsType = "vfat";
    };
  };

  services.rke2 = {
    enable = true;
    bootstrapManifests = [
      {
        path = "/data/usb1/secrets/*";
      }
      {
        type = "kustomization";
        path = "github.com/Litarvan/leviathan/k8s/bootstrap";
      }
    ];
  };
}
