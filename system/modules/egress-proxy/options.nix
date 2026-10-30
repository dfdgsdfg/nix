{ lib, ... }:
{
  options.modules.egressProxy = {
    enable = lib.mkEnableOption "tailnet-only SOCKS5 egress proxy for the homelab home-egress service";

    listenAddress = lib.mkOption {
      type = lib.types.strMatching "([0-9]{1,3}\\.){3}[0-9]{1,3}";
      example = "100.64.0.1";
      description = ''
        This device's Tailscale IPv4 address (`tailscale ip -4`). The proxy
        binds only to this address, never to 0.0.0.0, a LAN address, or
        loopback. There is deliberately no default.
      '';
    };

    port = lib.mkOption {
      type = lib.types.port;
      default = 1080;
      description = "TCP port the SOCKS5 proxy listens on.";
    };

    allowedClients = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [ "100.109.228.53" ]; # oci-default-01
      description = ''
        Tailscale IPv4 addresses allowed to connect. Enforced by the firewall on
        NixOS. Not enforced on nix-darwin: macOS has no simple per-source rule
        here, and microsocks' own `-w` whitelist only applies together with
        user/password auth, so on macOS the tailnet ACL is the enforcement
        point. Keep the ACL limited to these clients on TCP `port` either way.
      '';
    };
  };
}
