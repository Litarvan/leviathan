{ config, pkgs, ... }:

let
  vars = import ../../vars;
in
{
  networking.firewall = {
    allowedTCPPorts = [ 80 443 ];
    allowedUDPPorts = [ 80 443 ];
  };

  security.acme = {
    acceptTerms = true;
    defaults.email = "adrien1975" + "@" + "live.fr"; # TODO: Change

    certs = {
      "pxe.alligator.litarvan.dev" = {
        keyType = "rsa2048"; # iPXE does not support EC*
        extraLegoRunFlags = [ "--preferred-chain" "ISRG Root X1" ]; # iPXE is missing some root certificates
      };

      "litarvan.dev" = {
        domain = "*.litarvan.dev";
        dnsProvider = "netlify";
        credentialsFile = "/data/secrets/netlify.env";
        group = "nginx";
      };
    };
  };

  services.nginx = {
    enable = true;
    package = pkgs.nginxQuic;

    recommendedGzipSettings = true;
    recommendedOptimisation = true;
    recommendedProxySettings = true;
    recommendedTlsSettings = true;

    # iPXE does not support ECDHE ciphers and we can't use DHE ciphers so we need to add AES128-GCM-SHA256, even though it's weak
    sslCiphers = "ECDHE-ECDSA-AES128-GCM-SHA256:ECDHE-RSA-AES128-GCM-SHA256:ECDHE-ECDSA-AES256-GCM-SHA384:ECDHE-RSA-AES256-GCM-SHA384:ECDHE-ECDSA-CHACHA20-POLY1305:ECDHE-RSA-CHACHA20-POLY1305:DES-CBC3-SHA:AES128-GCM-SHA256";

    commonHttpConfig = ''
      ssl_early_data on;
      ssl_ecdh_curve secp384r1;

      add_header Expect-CT "max-age=0";
      add_header Strict-Transport-Security "max-age=63072000; includeSubDomains; preload" always;
      add_header X-Content-Type-Options "nosniff" always;
      add_header X-Frame-Options "SAMEORIGIN" always;
      add_header Referrer-Policy "no-referrer-when-downgrade" always;

      charset UTF-8;
    '';

    virtualHosts = {
      "pxe.alligator.litarvan.dev" = {
        enableACME = true;
        forceSSL = true;

        root = "/var/www/pxe";
      };

      "*.litarvan.dev" = {
        http2 = true;
        quic = true;

        useACMEHost = "litarvan.dev";
        forceSSL = true;

        locations."/" = {
          proxyPass = "https://${vars.wireguard.peers.leviathan-alpha.ips.v4}";
        };
      };
    };
  };
}
