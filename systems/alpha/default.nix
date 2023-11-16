{ lib, pkgs, ... }:

let
  vars = import ../../vars;
in
{
  boot = {
    initrd.availableKernelModules = [ "xhci_pci" "ehci_pci" "ahci" "usbhid" "sd_mod" ];
    kernelModules = [ "kvm-intel" "nvme" ];

    kernelParams = [ "module_blacklist=i915" ];

    netboot.enable = true;
    postBootCommands = ''
      mkdir -p /data/{nvme1,usb1}
      chmod 700 /data
    '';
  };

  powerManagement.cpuFreqGovernor = lib.mkDefault "performance";

  hardware.opengl = {
    enable = true;
    driSupport32Bit = true;
  };

  fileSystems = {
    "/data/nvme1" = {
      label = vars.diskLabels.leviathan-alpha.nvme1;
      fsType = "ext4";
    };

    "/data/usb1" = {
      label = vars.diskLabels.leviathan-alpha.usb1;
      fsType = "vfat";
      neededForBoot = true; # Else, /data/usb1 won't exist when litarvan's password file is read
      options = [ "ro,umask=077" ];
    };
  };

  # The file should contain a single line with the bcrypt hashed password.
  users.users.litarvan.passwordFile = "/data/usb1/secrets/litarvan-password";

  networking = {
    hostName = "leviathan-alpha";
    interfaces.eth0.useDHCP = true;

    wg-quick.interfaces.${vars.wireguard.interface} = {
      address = builtins.attrValues vars.wireguard.peers.leviathan-alpha.ips;
      privateKeyFile = "/data/usb1/secrets/wireguard-private-key";

      postUp = ''
        # When using privateKeyFile, the private-key is set in the postUp hook.
        # But the PersistentKeepAlive parameter is then "reset", so we must apply it again.
        wg set ${vars.wireguard.interface} peer ${vars.wireguard.peers.alligator.publicKey} persistent-keepalive 25

        # Kubernetes CIDRs must stay local
        ip route add 10.43.0.0/16 dev lo # Kubernetes intern CIDR must stay local; TODO: Use variables, edit when multi-node
      '';
      postDown = ''
        ip route delete 10.43.0.0/16 dev lo
      '';

      peers = [
        # Alligator
        {
          endpoint = "${vars.wireguard.peers.alligator.host}:${toString vars.wireguard.port}";
          publicKey = vars.wireguard.peers.alligator.publicKey;
          allowedIPs = [ "0.0.0.0/0" "::/0" ];
        }
      ];
    };
  };

  services = {
    xserver.videoDrivers = [ "nvidia" ];
    openssh.hostKeys = [
      {
        path = "/data/usb1/secrets/ssh-host-ed25519-key";
        type = "ed25519";
      }
    ];
    rke2 = {
      enable = true;
      bootstrapManifests = [
        {
          path = "/data/usb1/secrets/k8s/*";
        }
        {
          path = "https://raw.githubusercontent.com/NVIDIA/k8s-device-plugin/v0.14.1/nvidia-device-plugin.yml";
        }
        {
          type = "kustomization";
          path = "github.com/Litarvan/leviathan/k8s/bootstrap";
        }
      ];
    };
  };

  environment.systemPackages = with pkgs; [ nvidia-docker ];

  nix.settings.max-jobs = lib.mkDefault 4;
}
