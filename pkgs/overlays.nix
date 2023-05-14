{ lib }:

builtins.mapAttrs (name: path: final: prev: {
  ${name} = final.callPackage path {};
}) (import ./top-level/all-packages.nix)

