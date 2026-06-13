{ config, lib, pkgs, ... }:

{
  imports = [
    ./modules/fonts.nix
    ./modules/fish.nix
    ./modules/common.nix
    ./modules/neovim.nix
    ./modules/apps.nix
    ./modules/games.nix
    ./modules/dev.nix
    ./modules/ai.nix
  ];

  home.username = "dididi";
  home.homeDirectory = "/home/dididi";
  home.stateVersion = "26.05";

  home.sessionVariables = {
    EDITOR = "hx";
  };

  programs.home-manager.enable = true;

  fonts.fontconfig.enable = true;
  nixpkgs.config.allowUnfree = true;
}
