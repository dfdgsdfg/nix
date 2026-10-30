{ config, lib, pkgs, ... }:
let
  cfg = config.modules.egressProxy;
  tailscaleInterface = config.services.tailscale.interfaceName;
  portString = toString cfg.port;
in
{
  config = lib.mkIf cfg.enable (lib.mkMerge [
    {
      assertions = [
        {
          assertion = config.services.tailscale.enable;
          message = "modules.egressProxy needs services.tailscale.enable: the proxy only listens on the Tailscale address.";
        }
        {
          assertion = cfg.allowedClients != [ ];
          message = "modules.egressProxy.allowedClients must not be empty.";
        }
      ];

      systemd.services.egress-proxy = {
        description = "Tailnet-only SOCKS5 egress proxy (homelab home-egress upstream)";
        wantedBy = [ "multi-user.target" ];
        wants = [ "tailscaled.service" ];
        after = [ "tailscaled.service" ];

        # The Tailscale address may not exist yet at boot, so the bind fails and
        # microsocks exits. Keep retrying forever rather than tripping the
        # start-rate limit and staying down.
        unitConfig.StartLimitIntervalSec = 0;

        serviceConfig = {
          # -q: no per-connection logging (destinations are not worth keeping).
          # No -w and no -u/-P: -w only works together with auth, see options.nix.
          ExecStart = "${lib.getExe pkgs.microsocks} -q -i ${cfg.listenAddress} -p ${portString}";
          Restart = "always";
          RestartSec = "5s";

          DynamicUser = true;
          NoNewPrivileges = true;
          CapabilityBoundingSet = "";
          AmbientCapabilities = "";
          ProtectSystem = "strict";
          ProtectHome = true;
          PrivateTmp = true;
          PrivateDevices = true;
          ProtectKernelTunables = true;
          ProtectKernelModules = true;
          ProtectKernelLogs = true;
          ProtectControlGroups = true;
          ProtectClock = true;
          ProtectHostname = true;
          ProtectProc = "invisible";
          ProcSubset = "pid";
          RestrictAddressFamilies = [
            "AF_INET"
            "AF_INET6"
          ];
          RestrictNamespaces = true;
          RestrictRealtime = true;
          RestrictSUIDSGID = true;
          LockPersonality = true;
          MemoryDenyWriteExecute = true;
          RemoveIPC = true;
          SystemCallArchitectures = "native";
          SystemCallFilter = [
            "@system-service"
            "~@privileged"
          ];
          UMask = "0077";
        };
      };
    }

    # Open the port only on the Tailscale interface and only from allowedClients.
    # Do not use networking.firewall.interfaces.<if>.allowedTCPPorts: that opens
    # the port to every tailnet peer. The binding address (listenAddress) is a
    # second, independent limit.
    {
      # nftables backend: appended to the input-allow chain.
      networking.firewall.extraInputRules = lib.mkIf config.networking.nftables.enable (
        lib.concatMapStringsSep "\n" (
          client: ''iifname "${tailscaleInterface}" ip saddr ${client} tcp dport ${portString} accept''
        ) cfg.allowedClients
      );

      # iptables backend (the NixOS default; sg-lenovo uses it): extraCommands
      # runs after the port rules and before the final log-refuse rule. The
      # firewall script rebuilds nixos-fw on every (re)start, so no
      # extraStopCommands cleanup is needed. The proxy is IPv4 only.
      networking.firewall.extraCommands = lib.mkIf (!config.networking.nftables.enable) (
        lib.concatMapStringsSep "\n" (
          client:
          "iptables -w -A nixos-fw -i ${tailscaleInterface} -s ${client} -p tcp --dport ${portString} -j nixos-fw-accept"
        ) cfg.allowedClients
      );
    }
  ]);
}
