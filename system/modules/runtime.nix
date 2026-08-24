{ config, lib, ... }:
let
  cfg = config.modules.runtime;
in
{
  options.modules.runtime = {
    games.enable = lib.mkEnableOption "system-level game runtime support";
    nixLd.enable = lib.mkEnableOption "nix-ld compatibility loader";
  };

  config = {
    programs.gamescope.enable = lib.mkIf cfg.games.enable true;
    programs.gamemode.enable = lib.mkIf cfg.games.enable true;
    programs.steam.enable = lib.mkIf cfg.games.enable true;
    programs.nix-ld.enable = lib.mkIf cfg.nixLd.enable true;
  };
}
