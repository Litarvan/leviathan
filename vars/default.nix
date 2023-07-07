{
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