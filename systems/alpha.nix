{ lib, pkgs, ... }:

let
  alligatorHost = "alligator.litarvan.dev";
  vars = import ../vars;
in
{
  boot = {
    initrd.availableKernelModules = [ "xhci_pci" "ehci_pci" "ahci" "usbhid" "sd_mod" ];
    kernelModules = [ "kvm-intel" ];

    postBootCommands = ''
      mkdir -p /data/{nvme1,hdd1,usb1}
      chmod 700 /data
    '';
  };

  leviathan.netboot.enable = true;

  networking = {
    hostName = "leviathan-alpha";
    interfaces.eth0.useDHCP = true;

    wg-quick.interfaces.${vars.wireguard.interface} = {
      address = builtins.attrValues vars.wireguard.peers.leviathan-alpha.ips;
      privateKeyFile = "/data/usb1/secrets/wireguard-private-key";

      # When using privateKeyFile, the private-key is set in the postUp hook.
      # But the PersistentKeepAlive parameter is then "reset", so we must apply it again.
      postUp = ''
        wg set ${vars.wireguard.interface} peer ${vars.wireguard.peers.alligator.publicKey} persistent-keepalive 25
      '';

      peers = [
        # Alligator
        {
          endpoint = "${alligatorHost}:${vars.wireguard.port}";
          publicKey = vars.wireguard.peers.alligator.publicKey;
          allowedIPs = [ "0.0.0.0/0" "::/0" ];
        }
      ];
    };
  };

  services = {
    xserver.videoDrivers = [ "nvidia" ];
    rke2 = {
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
  };

  hardware = {
    opengl = {
      enable = true;
      driSupport32Bit = true;
    };
    nvidia.modesetting.enable = true;
  };

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
}
