{ ... }:
{
  imports = [
    ../../../profiles/nixos/wsl.nix
    ./ssh.nix
  ];

  networking.hostName = "sg-asus";

  # modules.egressProxy is intentionally not enabled here (third upstream of the
  # homelab home-egress proxy is deferred). Inside WSL the Tailscale address
  # belongs to the Windows host, so binding it needs WSL mirrored networking;
  # revisit once that is on and Tailscale runs where the distro can see it.
}
