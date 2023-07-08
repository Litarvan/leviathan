{
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