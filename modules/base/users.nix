{ config, lib, pkgs, ... }:

{
  users.users = {
    root.shell = pkgs.fish;

    litarvan = {
      description = "Adrien Navratil";
      isNormalUser = true;
      extraGroups = [ "wheel" ];
      shell = pkgs.fish;
      openssh.authorizedKeys.keyFiles = [ ../../litarvan.pub ];
    };
  };

  programs.fish.enable = true;

  services.openssh = {
    enable = true;
    ports = [ 36255 ];
    settings = {
      PasswordAuthentication = false;
      PermitRootLogin = "no";
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
          interactiveShellInit = ''
            clear
            echo
            ${lib.getExe pkgs.fastfetch}
            echo

            ${lib.getExe pkgs.starship} init fish | source
          '';
        };
      };
    };
  };
}
