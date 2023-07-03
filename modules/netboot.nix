# Derived from https://github.com/epita/nixpie/blob/master/modules/system/boot/netboot.nix
#          and https://github.com/epita/nixpie/blob/master/lib/make-squashfs.nix

{ config, lib, pkgs, ... }:

with lib;

let
  systemName = config.networking.hostName;
  downloadRoot = https://pxe.alligator.litarvan.dev;
  storeFile = ".lvth_store.squashfs";

  defaultNameserver = "1.1.1.1";

  labels = {
    root = "lvth_root";
    rw_store = "lvth_rw_store";
    home = "lvth_home";
  };
in
{
  options.netboot.enable = mkEnableOption "Set defaults for creating a netboot image";

  config = mkIf config.netboot.enable {
    # Don't build the GRUB menu builder script, since we don't need it
    # here and it causes a cyclic dependency.
    boot.loader.grub.enable = false;

    # !!! Hack - attributes expected by other modules.
    environment.systemPackages = [ pkgs.grub2_efi pkgs.grub2 pkgs.syslinux ];

    fileSystems = {
      "/" = {
        label = labels.root;
        fsType = "ext4";
      };

      # In stage 1, mount a tmpfs on top of /nix/store (the squashfs
      # image) to make this a live CD.
      "/nix/.ro-store" = {
        fsType = "squashfs";
        device = "/${storeFile}";
        options = [ "loop" ];
        neededForBoot = true;
      };

      "/nix/.rw-store" = {
        label = labels.rw_store;
        fsType = "ext4";
        neededForBoot = true;
      };

      "/nix/store" = {
        fsType = "overlay";
        device = "overlay";
        options = [
          "lowerdir=/nix/.ro-store"
          "upperdir=/nix/.rw-store/store"
          "workdir=/nix/.rw-store/work"
        ];
      };

      "/home" = {
        label = labels.home;
        fsType = "ext4";
      };
    };

    networking.useDHCP = mkForce true;
    boot.initrd = {
      availableKernelModules = [
        # To mount /nix/store
        "squashfs"
        "overlay"

        # SATA support
        "ahci"
        "ata_piix"
        "sata_inic162x"
        "sata_nv"
        "sata_promise"
        "sata_qstor"
        "sata_sil"
        "sata_sil24"
        "sata_sis"
        "sata_svw"
        "sata_sx4"
        "sata_uli"
        "sata_via"
        "sata_vsc"

        # NVMe
        "nvme"

        # Virtio (QEMU, KVM, etc.) support
        "virtio_pci"
        "virtio_blk"
        "virtio_scsi"
        "virtio_balloon"
        "virtio_console"
        "virtio_net"

        # Network support
        "ecb"
        "arc4"
        "bridge"
        "stp"
        "llc"
        "ipv6"
        "bonding"
        "8021q"
        "ipvlan"
        "macvlan"
        "af_packet"
        "xennet"
        "e1000"
        "e1000e"
        "igc"
      ];
      kernelModules = [
        "loop"
        "overlay"
      ];

      # For store downloading
      network.enable = true;
      network.udhcpc.extraArgs = [ "-t 10" "-A 10" ];
      extraUtilsCommands = ''
        copy_bin_and_libs ${pkgs.curl}/bin/curl
        copy_bin_and_libs ${pkgs.e2fsprogs}/bin/mke2fs
        copy_bin_and_libs ${pkgs.e2fsprogs}/bin/mkfs.ext4
      '';
    };

    ###
    ### Commands to execute on boot to download the system and configure it
    ### properly.
    ###

    # Network is done in preLVMCommands, which means it is already set up when
    # we get to postDeviceCommands
    boot.initrd.postDeviceCommands = ''
      echo "nameserver ${defaultNameserver}" > /etc/resolv.conf

      if ! mkfs.ext4 -F -L ${labels.rw_store} /dev/disk/by-label/${labels.rw_store}; then
        echo "Failed to cleanup rw store partition"
      fi

      if ! mkfs.ext4 -F -L ${labels.root} /dev/disk/by-label/${labels.root}; then
        echo "Failed to cleanup root partition"
      fi

      echo "Mounting target root at '$targetRoot'"
      mkdir -p $targetRoot
      mount -t ext4 /dev/disk/by-label/${labels.root} $targetRoot
      if ! curl ${downloadRoot}/${systemName}.squashfs -o $targetRoot/${storeFile}; then
        echo "Failed to download squashfs, booting will fail"
        fail
      fi
    '';

    # Usually, stage2Init is passed using the init kernel command line argument
    # but it would be inconvenient to manually change it to the right Nix store
    # path every time we rebuild an image. We just set it here and forget about
    # it.
    # Also, we cannot directly reference the current system.build.toplevel, as
    # it would cause an infinite recursion, so we have to put it in another
    # system.build artefact, in this case our squashfs, and use it from
    # there
    boot.initrd.postMountCommands = ''
      export stage2Init=$(cat $targetRoot/nix/store/stage2Init)
    '';

    boot.postBootCommands = ''
      # After booting, register the contents of the Nix store
      # in the Nix database in the tmpfs.
      ${config.nix.package}/bin/nix-store --load-db < /nix/store/nix-path-registration

      # nixos-rebuild also requires a "system" profile and an
      # /etc/NIXOS tag.
      touch /etc/NIXOS
      ${config.nix.package}/bin/nix-env -p /nix/var/nix/profiles/system --set /run/current-system
    '';

    ###
    ### Outputs from the configuration needed to boot.
    ###

    # Create the squashfs image that contains the Nix store.
    system.build.squashfs = with pkgs; stdenv.mkDerivation rec {
      name = "${systemName}.squashfs";

      nativeBuildInputs = [ squashfsTools ];

      buildCommand = ''
        mkdir $out

        closureInfo=${closureInfo { rootPaths = config.system.build.toplevel; }}

        # Also include a manifest of the closures in a format suitable
        # for nix-store --load-db.
        cp $closureInfo/registration nix-path-registration

        echo "${config.system.build.toplevel}/init" > stage2Init

        # Generate the squashfs image.
        mksquashfs \
          nix-path-registration stage2Init $(cat $closureInfo/store-paths) \
          $out/${name} \
          -keep-as-directory -all-root -b 32768 -comp lz4 \
          -reproducible -no-fragments
      '';
    };

    # Using the prepend argument here for system.build.initialRamdisk doesn't
    # work, so we just create an extra initrd and concatenate the two later.
    system.build.extraInitrd = pkgs.makeInitrd {
      name = "extraInitrd";
      inherit (config.boot.initrd) compressor;

      contents = [
        {
          # Required for curl
          object =
            config.environment.etc."ssl/certs/ca-certificates.crt".source;
          symlink = "/etc/ssl/certs/ca-certificates.crt";
        }
      ];
    };

    # Concatenate the required initrds.
    system.build.initrd = pkgs.runCommand "initrd" { } ''
      cat \
        ${config.system.build.initialRamdisk}/initrd \
        ${config.system.build.extraInitrd}/initrd \
        > $out
    '';

    system.build.toplevel-netboot = pkgs.runCommand "${systemName}.toplevel-netboot" { } ''
      mkdir -p $out
      cp ${config.system.build.kernel}/bzImage $out/${systemName}_bzImage
      cp ${config.system.build.initrd} $out/${systemName}_initrd
      cp ${config.system.build.squashfs}/${config.system.build.squashfs.name} $out/${systemName}.squashfs
    '';
  };
}
