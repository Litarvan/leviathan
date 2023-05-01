{ config, lib, pkgs, ... }:

with lib;
let
  cfg = config.services.rke2;
in
{
  # interface

  options.services.rke2 = {
    enable = mkEnableOption (lib.mdDoc "rke2");

    package = mkOption {
      type = types.package;
      default = pkgs.rke2;
      defaultText = literalExpression "pkgs.rke2";
      description = lib.mdDoc "Package that should be used for rke2";
    };

    role = mkOption {
      description = lib.mdDoc ''
        Whether rke2 should run as a server or agent.

        If it's a server:

        - By default it also runs workloads as an agent.
        - Starts by default as a standalone server using an embedded etcd datastore.
        - Configure `serverAddr` to join an already-initialized cluster.

        If it's an agent:

        - `serverAddr` is required.
      '';
      default = "server";
      type = types.enum [ "server" "agent" ];
    };

    serverAddr = mkOption {
      type = types.str;
      description = lib.mdDoc ''
        The rke2 server to connect to.

        Servers and agents need to communicate each other. Read
        [the networking requirements docs](https://docs.rke2.io/install/requirements#networking)
        to know how to configure the firewall.
      '';
      example = "https://10.0.0.10:6443";
      default = "";
    };

    token = mkOption {
      type = types.str;
      description = lib.mdDoc ''
        The rke2 token to use when connecting to a server.

        WARNING: This option will expose store your token unencrypted world-readable in the nix store.
        If this is undesired use the tokenFile option instead.
      '';
      default = "";
    };

    tokenFile = mkOption {
      type = types.nullOr types.path;
      description = lib.mdDoc "File path containing rke2 token to use when connecting to the server.";
      default = null;
    };

    extraFlags = mkOption {
      description = lib.mdDoc "Extra flags to pass to the rke2 command.";
      type = types.str;
      default = "";
      example = "--cluster-cidr 10.24.0.0/16 --node-name hello";
    };

    configPath = mkOption {
      type = types.nullOr types.path;
      default = null;
      description = lib.mdDoc "File path containing the rke2 YAML config. This is useful when the config is generated (for example on boot).";
    };
  };

  # implementation

  config = mkIf cfg.enable {
    assertions = [
      {
        assertion = cfg.role == "agent" -> (cfg.configPath != null || cfg.serverAddr != "");
        message = "serverAddr or configPath (with 'server' key) should be set if role is 'agent'";
      }
      {
        assertion = cfg.role == "agent" -> cfg.configPath != null || cfg.tokenFile != null || cfg.token != "";
        message = "token or tokenFile or configPath (with 'token' or 'token-file' keys) should be set if role is 'agent'";
      }
    ];

    environment.systemPackages = [ cfg.package ];

    systemd.services.rke2 = {
      description = "rke2 service";
      after = [ "firewall.service" "network-online.target" ];
      wants = [ "firewall.service" "network-online.target" ];
      wantedBy = [ "multi-user.target" ];
      path = optional config.boot.zfs.enabled config.boot.zfs.package;
      serviceConfig = {
        Type = "notify";
        KillMode = "process";
        Delegate = "yes";
        Restart = "always";
        RestartSec = "5s";
        LimitNOFILE = 1048576;
        LimitNPROC = "infinity";
        LimitCORE = "infinity";
        TasksMax = "infinity";
        TimeoutStartSec = 0;
        Environment = "PATH=/run/current-system/bin/sw:/run/wrappers/bin:${pkgs.iptables}/bin";
        ExecStart = concatStringsSep " \\\n " (
          [
            "${cfg.package}/bin/rke2 ${cfg.role}"
          ]
          ++ (optional (cfg.serverAddr != "") "--server ${cfg.serverAddr}")
          ++ (optional (cfg.token != "") "--token ${cfg.token}")
          ++ (optional (cfg.tokenFile != null) "--token-file ${cfg.tokenFile}")
          ++ (optional (cfg.configPath != null) "--config ${cfg.configPath}")
          ++ [ cfg.extraFlags ]
        );
        ExecStopPost = ''/bin/sh -c "${pkgs.systemd}/bin/systemd-cgls /system/slice/%n | grep -Eo '[0-9]+ (containerd|kubelet)' | awk '{print $1}' | xargs -r kill"'';
      };
    };
  };
}
