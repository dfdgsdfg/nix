{ config, lib, pkgs, ... }:

let
  cfg = config.modules.pi;
  piHome = "${config.home.homeDirectory}/.pi";
in
{
  options.modules.pi.enable = lib.mkEnableOption "Pi multi-model agent routing and configuration";

  config = lib.mkIf cfg.enable {
    # Keep settings.json and models.json mutable because Pi also records runtime
    # changelog versions, local model overrides, and dynamic provider state.
    # Only merge the managed policies and models owned here.
    home.activation.piConfig = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
      if [ -z "''${DRY_RUN:-}" ]; then
        ${pkgs.python3}/bin/python ${./merge-config.py} \
          --settings "${piHome}/agent/settings.json" \
          --models "${piHome}/agent/models.json" \
          --models-source ${./models.json}
      else
        echo "Would merge Pi settings into ${piHome}/agent/settings.json and models into ${piHome}/agent/models.json"
      fi
    '';
  };
}
