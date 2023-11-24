# Derived from https://github.com/NixOS/nixpkgs/blob/master/nixos/modules/services/cluster/k3s/default.nix

{ config, lib, pkgs, ... }:

with lib;

let
  cfg = config.services.rke2;
  # TODO: Move in a proper option!
  containerdConfig = pkgs.writeText "config.toml.impl" ''
version = 2
[plugins]
  [plugins."io.containerd.internal.v1.opt"]
    path = "/var/lib/rancher/rke2/agent/containerd"
  [plugins."io.containerd.grpc.v1.cri"]
    stream_server_address = "127.0.0.1"
    stream_server_port = "10010"
    enable_selinux = false
    enable_unprivileged_ports = true
    enable_unprivileged_icmp = true
    sandbox_image = "index.docker.io/rancher/pause:3.6"
    [plugins."io.containerd.grpc.v1.cri".containerd]
      snapshotter = "overlayfs"
      disable_snapshot_annotations = true
      default_runtime_name = "nvidia"

      [plugins."io.containerd.grpc.v1.cri".containerd.runtimes]
        [plugins."io.containerd.grpc.v1.cri".containerd.runtimes.runc]
          runtime_type = "io.containerd.runc.v2"
          [plugins."io.containerd.grpc.v1.cri".containerd.runtimes.runc.options]
            SystemdCgroup = true
        [plugins."io.containerd.grpc.v1.cri".containerd.runtimes.nvidia]
          privileged_without_host_devices = false
          runtime_engine = ""
          runtime_root = ""
          runtime_type = "io.containerd.runc.v2"
          [plugins."io.containerd.grpc.v1.cri".containerd.runtimes.nvidia.options]
            BinaryName = "/run/current-system/sw/bin/nvidia-container-runtime"
            SystemdCgroup = true
  '';
in
{
  # interface

  options.services.rke2 = {
    enable = mkEnableOption (mdDoc "rke2");

    package = mkOption {
      type = types.package;
      default = pkgs.rke2;
      defaultText = literalExpression "pkgs.rke2";
      description = mdDoc "Package that should be used for rke2";
    };

    role = mkOption {
      description = mdDoc ''
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
      description = mdDoc ''
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
      description = mdDoc ''
        The rke2 token to use when connecting to a server.

        WARNING: This option will expose store your token unencrypted world-readable in the nix store.
        If this is undesired use the tokenFile option instead.
      '';
      default = "";
    };

    tokenFile = mkOption {
      type = types.nullOr types.path;
      description = mdDoc "File path containing rke2 token to use when connecting to the server.";
      default = null;
    };

    extraFlags = mkOption {
      description = mdDoc "Extra flags to pass to the rke2 command.";
      type = types.str;
      default = "";
      example = "--cluster-cidr 10.24.0.0/16 --node-name hello";
    };

    configPath = mkOption {
      type = types.nullOr types.path;
      default = null;
      description = mdDoc "File path containing the rke2 YAML config. This is useful when the config is generated (for example on boot).";
    };

    bootstrapManifests = mkOption {
      type = types.listOf (types.attrsOf types.string);
      description = mdDoc "Path/URL of manifests to apply post cluster startup";
      default = [];
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

    boot.kernelModules = [
      "br_netfilter"
      "iptable_nat"
      "iptable_filter"
      "ip6table_nat"
      "ip6table_filter"
    ];

    environment = {
      systemPackages = [ cfg.package ];

      variables.KUBECONFIG = "/etc/rancher/rke2/rke2.yaml";
      extraInit = ''
        export PATH="/var/lib/rancher/rke2/bin:$PATH"
      '';
    };

    systemd.services.rke2 = {
      description = "RKE2 Kubernetes service";
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
        ExecStartPre = "/bin/sh -c '${pkgs.coreutils}/bin/mkdir -p /var/lib/rancher/rke2/agent/etc/containerd && ${pkgs.coreutils}/bin/cp ${containerdConfig} /var/lib/rancher/rke2/agent/etc/containerd/config.toml.tmpl'";
        ExecStart = concatStringsSep " \\\n " (
          [ "${cfg.package}/bin/rke2 ${cfg.role}" ]
          ++ (optional (cfg.serverAddr != "") "--server ${cfg.serverAddr}")
          ++ (optional (cfg.token != "") "--token ${cfg.token}")
          ++ (optional (cfg.tokenFile != null) "--token-file ${cfg.tokenFile}")
          ++ (optional (cfg.configPath != null) "--config ${cfg.configPath}")
          ++ [ cfg.extraFlags ]
        );
        ExecStopPost = ''/bin/sh -c "${pkgs.systemd}/bin/systemd-cgls /system.slice/%n | ${lib.getExe pkgs.gnugrep} -Eo '[0-9]+ (containerd|kubelet)' | ${lib.getExe pkgs.gawk} '{print $1}' | ${pkgs.findutils}/bin/xargs -r kill"'';
      };
    };

    systemd.services.leviathan-bootstrap = mkIf (cfg.bootstrapManifests != null) {
      description = "Leviathan bootstrap service";
      after = [ "rke2.service" ];
      wants = [ "rke2.service" ];
      wantedBy = [ "multi-user.target" ];
      serviceConfig = {
        Type = "oneshot";
        RemainAfterExit = "yes";
        TimeoutStartSec = 0;
        Environment = "PATH=/run/current-system/sw/bin";
        ExecStart = lib.getExe (pkgs.writeShellScriptBin "leviathan-bootstrap" (concatStringsSep "\n" (map ({ type ? "resource", path }: ''
          while true; do
            echo Waiting for cluster to be ready...
            if ! KUBECONFIG=/etc/rancher/rke2/rke2.yaml /var/lib/rancher/rke2/bin/kubectl wait --for=condition=Ready nodes --all --timeout=-1s; then
              echo Error waiting for cluster! Retrying in 5 seconds... # We can't use the Restart= option with oneshot services
              sleep 5
              echo
              continue
            fi

            echo Applying "${type}" "${path}"...
            KUBECONFIG=/etc/rancher/rke2/rke2.yaml /var/lib/rancher/rke2/bin/kubectl apply -"${if type == "kustomization" then "k" else "f"}" "${path}" && break
            echo Command failed! Retrying in 5 seconds...
            sleep 5
            echo
          done
          echo
        '') cfg.bootstrapManifests)));
      };
    };
  };
}
