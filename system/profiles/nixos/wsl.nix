{ inputs, pkgs, ... }:
{
  imports = [
    ./headless.nix
    inputs.nixos-wsl.nixosModules.wsl
  ];
  nix.registry.unstable.flake = inputs.nixpkgs-unstable;
  wsl.enable = true;
  wsl.defaultUser = "dididi";
  wsl.startMenuLaunchers = false;

  users.users.dididi.shell = pkgs.zsh;
  programs.zsh.enable = true;
  services.tailscale.enable = false;
  systemd.services.cloudflared.enable = false;
}
