{ inputs, pkgs, pkgsUnstable, lib, ... }:
{
  networking.hostName = "desktop";
  time.timeZone = "UTC";

  nix.settings = {
    experimental-features = [ "nix-command" "flakes" ];
    trusted-users = [ "root" "dididi" ];
  };
  nix.registry.unstable.flake = inputs.nixpkgs-unstable;

  boot.loader.systemd-boot.enable = lib.mkDefault true;
  boot.loader.efi.canTouchEfiVariables = lib.mkDefault true;

  users.users.dididi = {
    isNormalUser = true;
    description = "dididi";
    extraGroups = [ "wheel" "networkmanager" ];
    shell = pkgs.zsh;
    packages = with pkgs; [
      git
    ];
  };

  programs.zsh.enable = true;
  services.openssh.enable = true;
  networking.networkmanager.enable = true;

  environment.systemPackages =
    (with pkgs; [
      gnupg
      curl
      sops
    ]) ++ (with pkgsUnstable; [
      atuin
    ]);

  system.stateVersion = "26.05";
}
