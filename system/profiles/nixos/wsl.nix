{ inputs, ... }:
{
  imports = [
    ./headless.nix
    inputs.nixos-wsl.nixosModules.wsl
  ];
  nix.registry.unstable.flake = inputs.nixpkgs-unstable;
  wsl.enable = true;
  wsl.defaultUser = "dididi";
  wsl.startMenuLaunchers = false;

  # Allow mise-managed runtimes such as Node to execute their upstream
  # dynamically linked Linux binaries on NixOS.
  modules.runtime.nixLd.enable = true;

  services.tailscale.enable = false;
  systemd.services.cloudflared.enable = false;
}
