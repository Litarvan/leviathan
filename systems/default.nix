{ self, nixpkgs, home-manager, systemsPkgs, ... }:

let
  host = system: path:
    let
      modules = [
        path
        home-manager.nixosModules.home-manager
        {
          nix.nixPath = [
            "nixpkgs=${nixpkgs}"
            "leviathan=${self}"
          ];
          nixpkgs = {
            pkgs = systemsPkgs.${system};
            overlays = (builtins.attrValues self.overlays);
          };
          nix.registry = {
            nixpkgs.flake = nixpkgs;
            leviathan.flake = self;
          };
        }
      ] ++ builtins.attrValues self.nixosModules;
    in
    nixpkgs.lib.nixosSystem {
      inherit system;

      modules = modules ++ [
        ({ lib, modulesPath, ... }: {
          system.build.vm = (import "${modulesPath}/../lib/eval-config.nix" {
            inherit system;

            modules = modules ++ [
              "${modulesPath}/virtualisation/qemu-vm.nix"
              # { netboot.enable = lib.mkVMOverride false; }
            ];
          }).config.system.build.vm;
        })
      ];
    };
in
{
  alligator = host "aarch64-linux" ./alligator;
  leviathan-alpha = host "x86_64-linux" ./alpha.nix;
}
