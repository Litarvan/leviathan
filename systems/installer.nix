{ inputs, systemsPkgs, system }:

inputs.nixpkgs.lib.nixosSystem {
  inherit system;

  modules = [
    { nixpkgs.pkgs = systemsPkgs.${system}; }

    ({ lib, modulesPath, pkgs, ... }: {
      imports = [ "${modulesPath}/installer/cd-dvd/installation-cd-minimal.nix" ];

      image.baseName = lib.mkForce "leviathan-installer";

      # The machines are headless, so SSH is the only way in. The installer
      # profile already runs sshd and permits root login, it just has no key
      # to accept.
      users.users.root.openssh.authorizedKeys.keyFiles = [ ../litarvan.pub ];

      # Ships this flake on the ISO, so installing a host is:
      #   nixos-install --flake /etc/leviathan#leviathan-alpha
      environment = {
        etc = {
          leviathan.source = inputs.self;
        };
        systemPackages = [ pkgs.git ];
      };

      nix.settings.extra-experimental-features = [ "flakes" "nix-command" ];

      # The installer profile pulls in ZFS, and it never boots off a root pool.
      # This is the 26.11 default, setting it early silences the warning.
      boot.zfs.forceImportRoot = false;

      system.stateVersion = "26.05";
    })
  ];
}
