{ inputs, pkgs, pkgsUnstable, ... }:
{
  imports = [
    inputs.nixos-wsl.nixosModules.wsl
  ];

  networking.hostName = "sg-asus";

  wsl.enable = true;
  wsl.defaultUser = "dididi";
  wsl.startMenuLaunchers = false;

  nix.registry.unstable.flake = inputs.nixpkgs-unstable;
  nix.settings.experimental-features = [ "nix-command" "flakes" ];

  services.tailscale.enable = false;
  systemd.services.cloudflared.enable = false;

  modules.systemPackages.core.enable = true;

  environment.systemPackages = with pkgsUnstable; [
    yazi
  ];

  users.users.dididi = {
    isNormalUser = true;
    description = "dididi";
    shell = pkgs.zsh;
  };

  programs.zsh.enable = true;

  system.stateVersion = "26.05";
}
