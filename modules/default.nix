{
  core = import ./base/core.nix;
  netboot = import ./boot/netboot.nix;
  rke2 = import ./services/rke2.nix;
  users = import ./base/users.nix;
}