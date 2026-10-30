{ ... }:

{
  imports = [ ../../../profiles/darwin/base.nix ];
  networking.hostName = "sg-macbook";

  # First upstream of the homelab home-egress proxy (oci-default-01 -> here).
  # The tailnet ACL is the enforcement point on macOS; see modules.egressProxy.
  modules.egressProxy = {
    enable = true;
    listenAddress = "100.85.51.54";
  };
}
