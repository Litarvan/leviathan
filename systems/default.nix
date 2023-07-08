{ inputs, systemsPkgs, vars, ... }:

let
  host = with input.nixpkgs.lib.attrsets; system: path:
    let
      registry = (filterAttrs (name: _: name != "self") inputs) // { leviathan = inputs.self; };
      modules = [
        path
        home-manager.nixosModules.home-manager
        {
          nix = {
            nixPath = (mapAttrsToList (name: input: "${name}=${input}") inputs) ++ [ "nixos=${input.nixpkgs}" ];
            registry = mapAttrs (_: input: { flake = input; }) registry;
          };
          nixpkgs = {
            pkgs = systemsPkgs.${system};
            overlays = attrValues self.overlays;
          };
        }
      ] ++ (attrValues self.nixosModules);
    in
    nixpkgs.lib.nixosSystem {
      inherit system;

      modules = modules ++ [
        ({ lib, modulesPath, ... }: {
          system.build.vm = (import "${modulesPath}/../lib/eval-config.nix" {
            inherit system;

            modules = modules ++ [
              "${modulesPath}/virtualisation/qemu-vm.nix"
              { boot.netboot.enable = lib.mkVMOverride false; }
            ];
          }).config.system.build.vm;
        })
      ];
      specialArgs = { inherit vars; };
    };
in
{
  alligator = host "aarch64-linux" ./alligator;
  leviathan-alpha = host "x86_64-linux" ./alpha.nix;
}
