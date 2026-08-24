{ lib, ... }:
{
  imports = [
    ../../modules/desktop/fonts.nix
    ../../modules/desktop/gnome.nix
    ../../modules/desktop/apps.nix
    ../../modules/desktop/games.nix
    ../../modules/desktop/music.nix
    ../../modules/desktop/dev.nix
  ];

  home.stateVersion = "26.05";
  home.sessionVariables.EDITOR = lib.mkForce "hx";

  fonts.fontconfig.enable = true;

  nixpkgs.config = {
    android_sdk.accept_license = true;
    permittedInsecurePackages = [
      "electron-39.8.10"
    ];
  };
}
