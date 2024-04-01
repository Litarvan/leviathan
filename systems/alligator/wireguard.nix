{ pkgs, ... }:

let
  vars = import ../../vars;
in
{
  networking = {
    nat = {
      enable = true;
      enableIPv6 = true;

      externalInterface = "enp0s6";
      internalInterfaces = [ vars.wireguard.interface ];
    };

    firewall.allowedUDPPorts = [ vars.wireguard.port ];

    wg-quick.interfaces.${vars.wireguard.interface} = {
      address = builtins.attrValues vars.wireguard.peers.alligator.ips;
      listenPort = vars.wireguard.port;
      mtu = 1420; # Wireguard requires room for its header, by setting this, network speed goes from 0.5MB/s to 900MB/s :)

      privateKeyFile = "/data/secrets/wireguard-private-key";

      postUp = ''
        ${pkgs.iptables}/bin/iptables -A FORWARD -i ${vars.wireguard.interface} -j ACCEPT
        ${pkgs.iptables}/bin/iptables -t nat -A POSTROUTING -s ${vars.wireguard.peers.alligator.ips.v4} -o eth0 -j MASQUERADE
        ${pkgs.iptables}/bin/ip6tables -A FORWARD -i ${vars.wireguard.interface} -j ACCEPT
        ${pkgs.iptables}/bin/ip6tables -t nat -A POSTROUTING -s ${vars.wireguard.peers.alligator.ips.v6} -o eth0 -j MASQUERADE
      '';
      preDown = ''
        ${pkgs.iptables}/bin/iptables -D FORWARD -i ${vars.wireguard.interface} -j ACCEPT
        ${pkgs.iptables}/bin/iptables -t nat -D POSTROUTING -s ${vars.wireguard.peers.alligator.ips.v4} -o eth0 -j MASQUERADE
        ${pkgs.iptables}/bin/ip6tables -D FORWARD -i ${vars.wireguard.interface} -j ACCEPT
        ${pkgs.iptables}/bin/ip6tables -t nat -D POSTROUTING -s ${vars.wireguard.peers.alligator.ips.v6} -o eth0 -j MASQUERADE
      '';

      peers = [
        # Leviathan alpha
        {
          publicKey = vars.wireguard.peers.leviathan-alpha.publicKey;
          allowedIPs = builtins.attrValues vars.wireguard.peers.leviathan-alpha.ips;
        }
      ];
    };
  };
}