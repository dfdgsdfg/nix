{ config, lib, pkgs, ... }:

let
  cfg = config.modules.pi;
  piHome = "${config.home.homeDirectory}/.pi";
  isDarwin = pkgs.stdenv.hostPlatform.isDarwin;
  pnpmHome =
    if isDarwin then
      "${config.home.homeDirectory}/Library/pnpm"
    else
      "${config.home.homeDirectory}/.local/share/pnpm";
  brewPrefix = if pkgs.stdenv.hostPlatform.isAarch64 then "/opt/homebrew" else "/usr/local";
  mise = if isDarwin then "${brewPrefix}/bin/mise" else lib.getExe pkgs.mise;
  managedModels = builtins.fromJSON (builtins.readFile ./models.json);
  modelsSource = pkgs.writeText "pi-models.json" (builtins.toJSON (
    managedModels
    // {
      providers = managedModels.providers // {
        omniroute = managedModels.providers.omniroute // {
          apiKey = cfg.apiKeyCommand;
        };
      };
    }
  ));
in
{
  options.modules.pi = {
    enable = lib.mkEnableOption "Pi multi-model agent routing and configuration";

    apiKeyCommand = lib.mkOption {
      type = lib.types.str;
      default = ''!security find-generic-password -a "$USER" -s "omniroute-personal-pi" -w'';
      description = "Command Pi executes to read its OmniRoute client key from the platform secret store.";
    };
  };

  config = lib.mkIf cfg.enable {
    home.activation.piPackage = lib.hm.dag.entryBetween [ "piConfig" ] [ "writeBoundary" ] ''
      if [ -z "''${DRY_RUN:-}" ]; then
        if [ ! -x "${pnpmHome}/bin/pi" ]; then
          if [ ! -x "${mise}" ]; then
            echo "mise must be installed before installing Pi with pnpm" >&2
            exit 1
          fi

          export PNPM_HOME="${pnpmHome}"
          export PATH="$PNPM_HOME/bin:$PNPM_HOME:$PATH"
          ${mise} exec pnpm@latest -- \
            pnpm add --global --ignore-scripts @earendil-works/pi-coding-agent
        fi
      else
        echo "Would install Pi with pnpm when ${pnpmHome}/bin/pi is missing"
      fi
    '';

    # Keep settings.json and models.json mutable because Pi also records runtime
    # changelog versions, local model overrides, and dynamic provider state.
    # Only merge the managed policies and models owned here.
    home.activation.piConfig = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
      if [ -z "''${DRY_RUN:-}" ]; then
        ${pkgs.python3}/bin/python ${./merge-config.py} \
          --settings "${piHome}/agent/settings.json" \
          --models "${piHome}/agent/models.json" \
          --models-source ${modelsSource}
      else
        echo "Would merge Pi settings into ${piHome}/agent/settings.json and models into ${piHome}/agent/models.json"
      fi
    '';
  };
}
