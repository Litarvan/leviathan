{ lib, pkgs, ... }:

let
  sshKeys = {
    yubiForge = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIGoFiziKbq1TVgaiSp4SioutOG78WSkbJrrIYrKEYM5H cardno:16 097 343";
  };
in
{
  users.users.litarvan = {
    description = "Adrien Navratil";
    isNormalUser = true;
    extraGroups = [ "wheel" ];
    shell = pkgs.fish;
    openssh.authorizedKeys.keys = [ sshKeys.yubiForge ];
  };

  security.pam.yubico = {
     enable = true;
     debug = true;
     mode = "challenge-response";
     yubico.id = [ "16097343" ];
  };

  # We need this to do remote nixos-rebuild easily for now (TODO: remove it)
  users.users.root = {
   shell = pkgs.fish;
   openssh.authorizedKeys.keys = [ sshKeys.yubiForge ];
  };

  programs.fish.enable = true;

  services.openssh = {
    enable = true;
    ports = [ 36255 ];
    settings.PasswordAuthentication = false;
  };

  environment = {
    variables.KUBECONFIG = "/etc/rancher/rke2/rke2.yaml";
    extraInit = ''
      export PATH="/var/lib/rancher/rke2/bin:$PATH"
    '';
  };

  home-manager = {
    useGlobalPkgs = true;
    useUserPackages = true;
    users.litarvan = {
      home = {
        username = "litarvan";
        homeDirectory = "/home/litarvan";

        stateVersion = "23.05";
      };

      programs = {
        home-manager.enable = true;

        fish = {
          enable = true;
          interactiveShellInit = ''
            clear
            echo
            ${lib.getExe pkgs.neofetch}
            echo

            ${lib.getExe pkgs.starship} init fish | source
          '';
        };
      };
    };
  };
}
