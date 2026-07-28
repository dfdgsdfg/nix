{ config, pkgs, ... }:

let
  pruneHomeManagerGenerations = pkgs.writeShellApplication {
    name = "prune-home-manager-generations";
    runtimeInputs = with pkgs; [
      coreutils
      findutils
      nix
    ];
    text = ''
      ${pkgs.bash}/bin/bash ${../../../../../scripts/prune-nixos-generations.sh} \
        "${config.home.homeDirectory}/.local/state/nix/profiles/home-manager" 5 30
    '';
  };
in
{
  systemd.user.services.home-manager-generation-prune = {
    Unit.Description = "Prune old Home Manager generations";
    Service = {
      Type = "oneshot";
      ExecStart = "${pruneHomeManagerGenerations}/bin/prune-home-manager-generations";
    };
  };

  systemd.user.timers.home-manager-generation-prune = {
    Unit.Description = "Prune old Home Manager generations weekly";
    Timer = {
      OnCalendar = "weekly";
      Persistent = true;
      RandomizedDelaySec = "30m";
    };
    Install.WantedBy = [ "timers.target" ];
  };
}
