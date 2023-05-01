{ lib, pkgs }:

let
  allPackagesNames = builtins.attrNames (import ./top-level/all-packages.nix);
in
lib.filterAttrs (name: _: builtins.elem name allPackagesNames) pkgs
