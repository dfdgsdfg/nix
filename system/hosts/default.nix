{ inputs ? { } }:

let
  username = "dididi";
  darwinHome = "/Users/${username}";
  linuxHome = "/home/${username}";

  nixvimModules =
    if builtins.hasAttr "nixvim" inputs then
      [ inputs.nixvim.nixosModules.default ]
    else
      [ ];
in
{
  macbook = {
    type = "darwin";
    system = "aarch64-darwin";
    inherit username;
    homeDirectory = darwinHome;
    systemModules = [
      ./darwin/macbook
    ];
    homeModules = [
      ../../home/home.nix
    ];
    homePackageName = "default";
  };

  sg-macbook = {
    type = "darwin";
    system = "aarch64-darwin";
    inherit username;
    homeDirectory = darwinHome;
    systemModules = [
      ./darwin/sg-macbook
    ];
    homeModules = [
      ../../home/home.nix
    ];
    homePackageName = "sg-macbook";
  };

  desktop = {
    type = "nixos";
    systemEnabled = false;
    system = "x86_64-linux";
    inherit username;
    homeDirectory = linuxHome;
    systemModules = [
      ./nixos/desktop
    ];
    homeModules = [
      ../../home/home.nix
    ];
    homePackageName = "desktop";
  };

  sg-lenovo = {
    type = "nixos";
    system = "x86_64-linux";
    inherit username;
    homeDirectory = linuxHome;
    systemModules = [
      ./nixos/lenovo-ideapadslim3
    ] ++ nixvimModules;
    homeModules = [
      ../../home/home.nix
      ../../home/hosts/nixos/lenovo-ideapadslim3
    ];
    homePackageName = "sg-lenovo";
  };

  sg-asus = {
    type = "wsl";
    system = "x86_64-linux";
    inherit username;
    homeDirectory = linuxHome;
    systemModules = [
      ./wsl/sg-asus
    ];
    homeModules = [
      ../../home/home.nix
      ../../home/hosts/wsl/sg-asus
    ];
    homePackageName = "sg-asus";
  };
}
