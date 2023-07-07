{ config, lib, pkgs, ... }:

let
  sshKeys = {
    yubiForge = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIGoFiziKbq1TVgaiSp4SioutOG78WSkbJrrIYrKEYM5H cardno:16 097 343";
  };
  fishInit = ''
    clear
    echo
    ${lib.getExe pkgs.neofetch}
    echo

    ${lib.getExe pkgs.starship} init fish | source
  '';
in
{
  users.users = {
    root = {
     shell = pkgs.fish;
     openssh.authorizedKeys.keys = [ sshKeys.yubiForge ]; # TODO: Remove
    };

    litarvan = {
      description = "Adrien Navratil";
      isNormalUser = true;
      passwordFile = "/data/secrets/litarvan-password"; # Can be deleted on non-ephemeral machines (alligator) after user creation
      extraGroups = [ "wheel" ];
      shell = pkgs.fish;
      openssh.authorizedKeys.keys = [ sshKeys.yubiForge ];
    };
  };

  programs.fish.enable = true;

  services.openssh = {
    enable = true;
    ports = [ 36255 ];
    settings = {
      PasswordAuthentication = false;
      # PermitRootLogin = "no"; TODO: Add back
    };
  };

  home-manager = {
    useGlobalPkgs = true;
    useUserPackages = true;
    users.litarvan = {
      home = {
        username = "litarvan";
        homeDirectory = "/home/litarvan";

        stateVersion = lib.mkDefault config.system.stateVersion;
      };

      programs = {
        home-manager.enable = true;

        fish = {
          enable = true;
          interactiveShellInit = fishInit;
        };
      };
    };
  };
}
