{ modulesPath, pkgs, vars, ... }:

{
  imports = [
    (modulesPath + "/installer/scan/not-detected.nix")
  ];

  boot.kernelPackages = pkgs.linuxPackages_latest;

  console = {
    keyMap = "fr";
    font = "Lat2-Terminus16";
  };

  i18n.defaultLocale = "en_US.UTF-8";
  time.timeZone = vars.timeZone;

  networking = {
    useDHCP = true;
    dhcpcd = {
      wait = "any"; # Make sure we get an IP before marking the service as up
      extraConfig = ''
        noipv4ll
      '';
    };
    nameservers = [ vars.nameserver ]; # For some reason, rke2 will fail if we put more than 1
  };

  security.protectKernelImage = true;
  hardware.enableRedistributableFirmware = true;

  environment.systemPackages = with pkgs; [ vim git ];

  nix = {
    package = pkgs.nixVersions.nix_2_16;
    settings.extra-experimental-features = [ "flakes" "nix-command" "repl-flake" ];
  };
  nixpkgs.config.allowUnfree = true;
}
