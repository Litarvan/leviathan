{ lib, ... }:

{
  boot = {
    initrd.availableKernelModules = [ "xhci_pci" "ehci_pci" "ahci" "usbhid" "sd_mod" ];
    kernelModules = [ "kvm-intel" ];
  };

  networking = {
    hostName = "leviathan-alpha";
    interfaces.eth0.useDHCP = true;
  };

  nixpkgs.config.allowUnfree = true;

  services.xserver.videoDrivers = [ "nvidia" ];
  hardware.opengl = {
    enable = true;
    driSupport32Bit = true;
  };
  hardware.nvidia.modesetting.enable = true;

  nix.settings = {
    extra-experimental-features = [ "flakes" "nix-command" "repl-flake" ];
    max-jobs = lib.mkDefault 4;
  };
  powerManagement.cpuFreqGovernor = lib.mkDefault "powersave";

  fileSystems = {
    "/" = {
      label = "leviathan_root";
      fsType = "ext4";
    };

    "/data" = {
      label = "leviathan_data";
      fsType = "ext4";
    };

    "/secrets" = {
      label = "leviathan_secret";
      fsType = "ext4";
    };
  };

  services.rke2 = {
    enable = true;
    bootstrapManifests = [
      {
        path = "/secrets/*";
      }
      {
        type = "kustomization";
        path = "github.com/Litarvan/leviathan/k8s/bootstrap";
      }
    ];
  };
}
