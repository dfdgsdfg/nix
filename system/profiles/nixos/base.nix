{ inputs, pkgs, ... }:
{
  nix.registry.unstable.flake = inputs.nixpkgs-unstable;
  nix.settings = {
    experimental-features = [ "nix-command" "flakes" ];
    extra-substituters = [ "https://nix-community.cachix.org" ];
    extra-trusted-public-keys = [
      "nix-community.cachix.org-1:mB9FSh9qf2dCimDSUo8Zy7bkq5CX+/rkCWyvRCYg3Fs="
    ];
  };
  programs.fish.enable = true;

  users.users.dididi = {
    isNormalUser = true;
    description = "dididi";
    shell = pkgs.fish;
  };
  system.stateVersion = "26.05";
}
