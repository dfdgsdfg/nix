{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.modules.systemPackages;
in
{
  options.modules.systemPackages = {
    core.enable = lib.mkEnableOption "baseline system packages";
    workstation.enable = lib.mkEnableOption "interactive workstation system packages";
  };

  config.environment.systemPackages = lib.unique (
    [ pkgs.helix ]
    ++ lib.concatLists [
      (lib.optionals cfg.core.enable (
        with pkgs;
        [
          curl
          git
          gnupg
          sops
        ]
      ))
      (lib.optionals cfg.workstation.enable (
        with pkgs;
        [
          starship
          trashy
        ]
      ))
    ]
  );
}
