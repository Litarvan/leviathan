{ config, lib, pkgs, ... }:

{
  boot = {
    initrd.availableKernelModules = [ "xhci_pci" "ehci_pci" "ahci" "usbhid" "sd_mod" ];
    kernelModules = [
      "br_netfilter"
      "iptable_nat"
      "iptable_filter"
      "ip6table_nat"
      "ip6table_filter"
      "kvm-intel"
      "nvme"
    ];

    kernelParams = [ "module_blacklist=i915" ];

    loader = {
      systemd-boot.enable = true;
      efi.canTouchEfiVariables = true;
    };
  };

  powerManagement.cpuFreqGovernor = lib.mkDefault "performance";

  hardware = {
    graphics = {
      enable = true;
      enable32Bit = true;
    };

    nvidia = {
      # The GTX 1050 is Pascal: the open kernel modules need a GSP-capable GPU (Turing and newer)
      open = false;

      # 580 is the last branch supporting Maxwell/Pascal/Volta, the default (595) dropped them
      package = config.boot.kernelPackages.nvidiaPackages.legacy_580;
    };
    nvidia-container-toolkit.enable = true;
  };

  fileSystems = {
    "/" = {
      label = "lvth_root";
      fsType = "ext4";
    };

    "/boot" = {
      label = "LVTH_BOOT";
      fsType = "vfat";
      options = [ "fmask=0077" "dmask=0077" ];
    };

    "/home" = {
      label = "lvth_home";
      fsType = "ext4";
    };

    "/data/nvme1" = {
      label = "lvth_data_nvme1";
      fsType = "ext4";
    };
  };

  networking = {
    hostName = "leviathan-alpha";
    interfaces.eth0.useDHCP = true;
    firewall = {
      # 30103 is the qbittorrent NodePort. Re-add 30101 (minecraft) and 30102
      # (palworld) if those apps are registered in ArgoCD again.
      allowedTCPPorts = [ 80 443 30103 ];
      allowedUDPPorts = [ 443 30103 ];
    };
  };

  services = {
    xserver.videoDrivers = [ "nvidia" ];
    rke2 = {
      enable = true;

      extraFlags = [
        # Traefik only becomes the default in 1.36
        "--ingress-controller=traefik"

        # Make nvidia the cluster-wide default runtime. rke2 renders this as
        # default_runtime_name in the base containerd template AND validates it
        # up front against the runtimes it discovers: findContainerRuntimes() does
        # an exec.LookPath("nvidia-container-runtime"), so the binary has to be on
        # the rke2-server unit's PATH (see systemd.services.rke2-server.path below).
        # That same discovery makes the base template emit the runtimes.nvidia
        # block on its own, so no custom containerdConfigTemplate is needed.
        #
        # nvidia-cdi (nvidia-container-runtime.cdi), not nvidia: without a
        # /etc/nvidia-container-runtime/config.toml -- and the NixOS module writes
        # none, it only generates the CDI spec in /run/cdi -- the plain runtime
        # runs in "auto" mode, picks JIT CDI, and tries to dlopen libcuda.so.1 to
        # locate the driver libraries. That lookup segfaults on NixOS (invalid
        # free in internal/lookup.dlopenLocator), so every container carrying
        # NVIDIA_VISIBLE_DEVICES dies with "nvidia-container-runtime did not
        # terminate successfully: exit status 2". The .cdi variant pins mode=cdi
        # and consumes the pre-generated spec instead, skipping that code path.
        "--default-runtime=nvidia-cdi"
      ];

      # No .yaml/.yml suffix on the attribute names: rke2 rewrites every YAML
      # manifest in place at startup to pass CLI values through, which fails on
      # the read-only /nix/store symlinks the module creates. The nixpkgs module
      # dodges this by targeting .json instead (rke2 skips those), but only for
      # names that don't already carry an extension. The addon controller reads
      # .json files with a YAML parser, so the sources stay plain YAML.
      manifests = {
        rke2-traefik-config.source = ./rke2/rke2-traefik-config.yaml;
        traefik-headers.source = ./rke2/traefik-headers.yaml;

        nvidia-device-plugin.source = pkgs.fetchurl {
          url = "https://raw.githubusercontent.com/NVIDIA/k8s-device-plugin/v0.17.4/deployments/static/nvidia-device-plugin.yml";
          hash = "sha256-xPVGIl1k9yDqU9KLnfZ9ZyazKqhMoVX4xvKPuGP7p0o=";
        };
      };
    };
  };

  # rke2 discovers container runtimes with exec.LookPath, which only searches the
  # unit's PATH. NixOS gives units a minimal PATH (coreutils/findutils/grep/sed/
  # systemd) that never includes /run/current-system/sw/bin, so without this the
  # nvidia runtime is invisible and --default-runtime=nvidia fails validation with
  # "default runtime nvidia was not found". nvidia-docker used to pull the runtime
  # in, but upstream split them apart: it is now only a Docker CLI wrapper, so we
  # point at the nvidia-container-runtime in the toolkit's "tools" output directly.
  # containerd inherits this PATH, so the runtime's helpers (nvidia-container-cli,
  # the OCI hook) resolve from the same output.
  systemd.services.rke2-server.path = [ (lib.getOutput "tools" pkgs.nvidia-container-toolkit) ];

  environment = {
    variables.KUBECONFIG = "/etc/rancher/rke2/rke2.yaml";

    extraInit = ''
      export PATH="/var/lib/rancher/rke2/bin:$PATH"
    '';
  };

  nix.settings.max-jobs = lib.mkDefault 4;

  system.stateVersion = "26.05";
}
