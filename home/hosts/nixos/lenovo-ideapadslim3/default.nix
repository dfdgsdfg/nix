{ lib, ... }:

{
  imports = [
    ./modules/fonts.nix
    ./modules/ssh.nix
    ./modules/gnome.nix
    ./modules/apps.nix
    ./modules/games.nix
    ./modules/music.nix
    ./modules/dev.nix
  ];

  home.stateVersion = "26.05";
  home.sessionVariables.EDITOR = lib.mkForce "hx";

  modules.omp.apiKeyCommand = "!secret-tool lookup service omniroute client sg-lenovo-omp";

  fonts.fontconfig.enable = true;

  nixpkgs.config = {
    android_sdk.accept_license = true;
    permittedInsecurePackages = [
      "electron-39.8.10"
    ];
  };
}
