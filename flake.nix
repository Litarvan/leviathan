{
  description = "Leviathan infrastructure";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-23.05";
    flake-utils.url = "github:numtide/flake-utils";
    home-manager = {
      url = "github:nix-community/home-manager/release-23.05";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = { self, nixpkgs, flake-utils, home-manager }:
    let
      inherit (nixpkgs) lib;

      systemsPkgs = builtins.listToAttrs (map (system: {
        name = system;
        value = import nixpkgs {
          inherit system;

          overlays = builtins.attrValues self.overlays;
          config.allowUnfree = true;
        };
      }) flake-utils.lib.defaultSystems);
    in
    (flake-utils.lib.eachDefaultSystem (system:
      let
        pkgs = systemsPkgs.${system};
      in
      {
        packages = import ./pkgs { inherit lib pkgs; };
      }
    )) // {
      inherit systemsPkgs;
      overlays = import ./pkgs/overlays.nix { inherit lib; };

      nixosModules = import ./modules;
      nixosConfigurations = import ./systems { inherit self nixpkgs home-manager systemsPkgs; };
    };
}
