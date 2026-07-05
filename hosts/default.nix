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
      ../home/home.nix
      ../home/hosts/darwin/macbook
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
      ../home/home.nix
      ../home/hosts/darwin/sg-macbook
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
      ../home/home.nix
    ];
    homePackageName = "desktop";
  };

  lenovo-ideapadslim3 = {
    type = "nixos";
    system = "x86_64-linux";
    inherit username;
    homeDirectory = linuxHome;
    systemModules = [
      ./nixos/lenovo-ideapadslim3
    ] ++ nixvimModules;
    homeModules = [
      ../home/hosts/nixos/lenovo-ideapadslim3
    ];
    homePackageName = "lenovo-ideapadslim3";
  };

  wsl = {
    type = "wsl";
    system = "x86_64-linux";
    inherit username;
    homeDirectory = linuxHome;
    systemModules = [
      ./wsl/default
    ];
    homeModules = [
      ../home/home.nix
      ../home/hosts/wsl/default
    ];
    homePackageName = "wsl";
  };
}
