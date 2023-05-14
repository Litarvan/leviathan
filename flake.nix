{
  description = "Leviathan infrastructure";

  inputs.nixpkgs.url = "github:NixOS/nixpkgs/nixos-22.11";

  outputs = { self, nixpkgs }:
    let
      inherit (nixpkgs) lib;

      system = "x86_64-linux";
      pkgs = import nixpkgs {
        inherit system;
        overlays = builtins.attrValues self.overlays;
        config.allowUnfree = true;
      };
    in
    {
      overlays = import ./pkgs/overlays.nix { inherit lib; };
      packages.${system} = import ./pkgs { inherit lib pkgs; };

      nixosModules = import ./modules;
      nixosConfigurations = import ./images { inherit self nixpkgs pkgs lib; };
    };
}
