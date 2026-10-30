{ config, lib, pkgs, ... }:
let
  cfg = config.modules.egressProxy;
  logFile = "/var/log/egress-proxy.log";
in
{
  config = lib.mkIf cfg.enable {
    assertions = [
      {
        assertion = cfg.allowedClients != [ ];
        message = "modules.egressProxy.allowedClients must not be empty (it documents the tailnet ACL).";
      }
    ];

    # macOS has no simple per-source firewall here, so allowedClients is not
    # enforced on this host. The only controls are the bind address
    # (listenAddress) and the tailnet ACL, which must allow only allowedClients
    # to reach this device on TCP `port`. microsocks' `-w` whitelist is not used:
    # it only exempts listed IPs from user/password auth and rejects startup
    # without -u/-P, so it cannot deny anyone.
    launchd.daemons.egress-proxy.serviceConfig = {
      Label = "org.nixos.egress-proxy";
      ProgramArguments = [
        (lib.getExe pkgs.microsocks)
        "-q"
        "-i"
        cfg.listenAddress
        "-p"
        (toString cfg.port)
      ];
      UserName = "nobody";
      GroupName = "nobody";
      RunAtLoad = true;
      # The bind fails until Tailscale has brought the address up; launchd
      # restarts the process every ThrottleInterval seconds until it succeeds.
      KeepAlive = true;
      ThrottleInterval = 10;
      StandardOutPath = logFile;
      StandardErrorPath = logFile;
    };

    # launchd runs the job as nobody, which cannot create files in /var/log.
    system.activationScripts.postActivation.text = ''
      if [ ! -e ${logFile} ]; then
        /usr/bin/install -m 0644 -o nobody -g nobody /dev/null ${logFile}
      fi
    '';
  };
}
