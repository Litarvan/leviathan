{ pkgs, modulesPath, ... }:

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
  time.timeZone = "Europe/Paris";

  environment.systemPackages = with pkgs; [ vim git ];

  networking.nameservers = [ "1.1.1.1" ];

  nix = {
    package = pkgs.nixVersions.nix_2_16;
    settings.extra-experimental-features = [ "flakes" "nix-command" "repl-flake" ];
  };
  nixpkgs.config.allowUnfree = true;
}
