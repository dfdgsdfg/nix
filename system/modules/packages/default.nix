{ config, lib, pkgs, pkgsUnstable, ... }:
let
  cfg = config.modules.systemPackages;

  corePkgs = with pkgs; [
    curl
    git
    gnupg
    sops
  ];

  workstationPkgs = with pkgs; [
    helix
    starship
    trashy
  ];

  fishPkgs = with pkgs; [
    fishPlugins.grc
    grc
  ];

  darwinApps =
    lib.optionals pkgs.stdenv.isDarwin (
      (with pkgs; [
        androidStudioPackages.stable
        handbrake
        logseq
        rustdesk
        vlc
        wireshark
      ])
      ++ (with pkgsUnstable; [
        ghostty
        zed-editor
      ])
    );
in
{
  options.modules.systemPackages = {
    core.enable = lib.mkEnableOption "baseline system packages";
    workstation.enable = lib.mkEnableOption "interactive workstation system packages";
    fish.enable = lib.mkEnableOption "fish shell and system-level fish helpers";
    darwinApps.enable = lib.mkEnableOption "Darwin GUI applications installed at system level";
    games.enable = lib.mkEnableOption "system-level game runtime support";
    nixLd.enable = lib.mkEnableOption "nix-ld compatibility loader";
  };

  config = {
    environment.systemPackages = lib.unique (
      lib.concatLists [
        (lib.optionals cfg.core.enable corePkgs)
        (lib.optionals cfg.workstation.enable workstationPkgs)
        (lib.optionals cfg.fish.enable fishPkgs)
        (lib.optionals cfg.darwinApps.enable darwinApps)
      ]
    );

    programs.fish.enable = lib.mkIf cfg.fish.enable true;
    programs.gamescope.enable = lib.mkIf cfg.games.enable true;
    programs.gamemode.enable = lib.mkIf cfg.games.enable true;
    programs.steam.enable = lib.mkIf (cfg.games.enable && pkgs.stdenv.isLinux) true;
    programs.nix-ld.enable = lib.mkIf cfg.nixLd.enable true;
  };
}
