{ config, lib, pkgs, vars, ... }:

{
  users.users = {
    root = {
     shell = pkgs.fish;
     openssh.authorizedKeys.keys = [ vars.ssh.key ]; # TODO: Remove
    };

    litarvan = {
      description = "Adrien Navratil";
      isNormalUser = true;
      extraGroups = [ "wheel" ];
      shell = pkgs.fish;
      openssh.authorizedKeys.keys = [ vars.ssh.key ];
    };
  };

  programs.fish.enable = true;

  services.openssh = {
    enable = true;
    ports = [ vars.ssh.port ];
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
