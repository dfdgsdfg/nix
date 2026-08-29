{ inputs, pkgs, ... }:
{
  nix.registry.unstable.flake = inputs.nixpkgs-unstable;
  nix.settings.experimental-features = [ "nix-command" "flakes" ];
  programs.fish.enable = true;

  users.users.dididi = {
    isNormalUser = true;
    description = "dididi";
    shell = pkgs.fish;
  };
  system.stateVersion = "26.05";
}
