{ inputs, pkgs, pkgsUnstable, ... }:
{
  imports = [
    inputs.nixos-wsl.nixosModules.wsl
    inputs.home-manager.nixosModules.home-manager
  ];

  networking.hostName = "wsl";

  wsl.enable = true;
  wsl.defaultUser = "dididi";
  wsl.startMenuLaunchers = true;

  nix.registry.unstable.flake = inputs.nixpkgs-unstable;
  nix.settings.experimental-features = [ "nix-command" "flakes" ];

  environment.systemPackages =
    (with pkgs; [
      git
      gnupg
      sops
    ]) ++ (with pkgsUnstable; [
      yazi
    ]);

  users.users.dididi = {
    isNormalUser = true;
    description = "dididi";
    shell = pkgs.zsh;
  };

  programs.zsh.enable = true;

  system.stateVersion = "25.05";

  home-manager.useGlobalPkgs = true;
  home-manager.useUserPackages = true;
  home-manager.users.dididi = {
    imports = [ ../../home/home.nix ];
    home.username = "dididi";
    home.homeDirectory = "/home/dididi";
  };
}
