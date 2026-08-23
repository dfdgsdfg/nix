{ config, lib, pkgs, ... }:

let
  cfg = config.modules.omp;
  ompAgentHome = "${config.home.homeDirectory}/.omp/agent";
  python = pkgs.python3.withPackages (pythonPackages: [ pythonPackages.pyyaml ]);
in
{
  options.modules.omp = {
    enable = lib.mkEnableOption "OMP (Oh My Pi) model routing and policy";

    apiKeyCommand = lib.mkOption {
      type = lib.types.str;
      default = ''!security find-generic-password -a "$USER" -s "omniroute-us-mbp-omp-deepseek" -w'';
      description = "Command OMP executes to read its OmniRoute client key from the platform secret store.";
    };
  };

  config = lib.mkIf cfg.enable {
    home.file = {
      ".omp/agent/RULES.md" = {
        source = ./RULES.md;
        force = true;
      };
    };

    # Keep config.yml and models.yml mutable because OMP updates them at runtime.
    # Merge the managed routing blocks and provider catalog while preserving unrelated
    # top-level keys. Provider credentials remain outside the Nix store in the
    # platform secret store; only the lookup command is managed here.
    home.activation.ompConfig = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
      if [ -z "''${DRY_RUN:-}" ]; then
        OMP_API_KEY_COMMAND=${lib.escapeShellArg cfg.apiKeyCommand} \
          ${python}/bin/python ${./merge-config.py} "${ompAgentHome}"
      else
        echo "Would merge OMP configuration into ${ompAgentHome}/config.yml and ${ompAgentHome}/models.yml"
      fi
    '';
  };
}
