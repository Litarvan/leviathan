{ self, lib, ... }:

let
  host = path:
    let
      modules = [ path ] ++ builtins.attrValues self.nixosModules;
    in
    lib.nixosSystem {
      system = "x86_64-linux";
      modules = modules ++ [
        ({ lib, modulesPath, ... }: {
          system.build.vm = (import "${modulesPath}/../lib/eval-config.nix" {
            system = "x86_64-linux";
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
  leviathan-alpha = host ./alpha.nix;
}