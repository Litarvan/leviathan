rec {
  acmeEmail = "adrien1975" + "@" + "live.fr"; # TODO: Change

  domains = {
    root = "litarvan.dev";
    subRoots = [ "alligator.litarvan.dev" "leviathan.litarvan.dev" "meow.litarvan.dev" ];

    alligator = "alligator.${domains.root}";
    pxe = "pxe.${domains.alligator}";
  };

  pxeRemote = "https://${domains.pxe}";

  diskLabels = {
    root = "lvth_root";
    rw_store = "lvth_rw_store";
    home = "lvth_home";

    leviathan-alpha = {
      usb1 = "LVTH_ALPHA";
      nvme1 = "lvth_data_nvme1";
    };
  };

  timeZone = "Europe/Paris";

  nameserver = "1.1.1.1";

  ssh = {
    port = 36255;
    key = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIGoFiziKbq1TVgaiSp4SioutOG78WSkbJrrIYrKEYM5H cardno:16 097 343";
  };

  wireguard = {
    interface = "alligator-guard";
    port = 18635;

    peers = {
      alligator = {
        host = domains.alligator;
        ips = {
          v4 = "10.0.1.1/24";
          v6 = "fc00::1/64";
        };
        publicKey = "PGjLkVH2Fvrgqhnk0PoU8dRmExRdiQFPt0PbGvTlTWw=";
      };
      leviathan-alpha = {
        ips = {
          v4 = "10.0.1.2/32";
          v6 = "fc00::2/128";
        };
        publicKey = "G0GWFJQ7Hwet89jMX5zzXSovM0vYZFaLC0t3Tau3Qn4=";
      };
    };
  };
}
