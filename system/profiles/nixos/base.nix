{ inputs, ... }:
{
  nix.registry.unstable.flake = inputs.nixpkgs-unstable;
  nix.settings.experimental-features = [ "nix-command" "flakes" ];
  users.users.dididi = {
    isNormalUser = true;
    description = "dididi";
  };
  system.stateVersion = "26.05";
}
