{ pkgs, ... }:

{
  users.users.litarvan = {
    description = "Adrien Navratil";
    isNormalUser = true;
    createHome = true;
    extraGroups = [ "wheel" ];
    shell = pkgs.fish;
    openssh.authorizedKeys.keys = [
      "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIGoFiziKbq1TVgaiSp4SioutOG78WSkbJrrIYrKEYM5H cardno:16 097 343"
    ];
  };

  programs.fish.enable = true;

  services.openssh = {
    enable = true;
    ports = [ 35255 ];
    permitRootLogin = "no";
    passwordAuthentication = false;
  };
}