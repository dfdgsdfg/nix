{ inputs, pkgs, ... }:
{
  imports = [
    ./homebrew
  ];

  system.primaryUser = "dididi";

  nixpkgs = {
    hostPlatform = "aarch64-darwin";
    config.allowUnfreePredicate = _: true;
  };

  determinateNix = {
    enable = true;
    registry.unstable.flake = inputs.nixpkgs-unstable;
    customSettings.experimental-features = [
      "nix-command"
      "flakes"
    ];
  };

  users.users.dididi = {
    home = "/Users/dididi";
    shell = pkgs.zsh;
  };

  modules.systemPackages.core.enable = true;

  fonts.packages = [
    pkgs.nerd-fonts.meslo-lg
  ];

  programs.zsh.enable = true;

  system.stateVersion = 6;
}
