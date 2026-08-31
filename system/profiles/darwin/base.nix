{ inputs, pkgs, ... }:
{
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
    shell = pkgs.fish;
  };

  fonts.packages = [
    pkgs.nerd-fonts.meslo-lg
  ];

  environment.shells = [ pkgs.fish ];

  programs.fish.enable = true;
  programs.zsh.enable = true;

  system.stateVersion = 6;
}
