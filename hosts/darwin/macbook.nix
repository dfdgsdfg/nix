{ inputs, pkgs, pkgsUnstable, ... }:
{
  imports = [
    inputs.home-manager.darwinModules.home-manager
  ];

  networking.hostName = "macbook";
  nixpkgs = {
    hostPlatform = "aarch64-darwin";
    config.allowUnfreePredicate = _: true;
  };

  nix.settings.experimental-features = [ "nix-command" "flakes" ];
  nix.registry.unstable.flake = inputs.nixpkgs-unstable;
  services.nix-daemon.enable = true;

  users.users.dididi = {
    home = "/Users/dididi";
    shell = pkgs.zsh;
  };

  environment.systemPackages =
    (with pkgs; [
      androidStudioPackages.stable
      git
      gnupg
      handbrake
      logseq
      rustdesk
      sops
      vlc
      wireshark
    ])
    ++ (with pkgsUnstable; [
      ghostty
      zed-editor
    ]);

  fonts.fonts = [
    (pkgs.nerdfonts.override { fonts = [ "Meslo" ]; })
  ];

  programs.zsh.enable = true;

  system.stateVersion = 6;

  home-manager.useGlobalPkgs = true;
  home-manager.useUserPackages = true;
  home-manager.users.dididi = {
    imports = [ ../../home/home.nix ];
    home.username = "dididi";
    home.homeDirectory = "/Users/dididi";
  };
}
