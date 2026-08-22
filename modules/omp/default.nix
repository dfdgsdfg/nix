{ config, lib, pkgs, ... }:

let
  cfg = config.modules.omp;
  ompAgentHome = "${config.home.homeDirectory}/.omp/agent";
  python = pkgs.python3.withPackages (pythonPackages: [ pythonPackages.pyyaml ]);
in
{
  options.modules.omp.enable = lib.mkEnableOption "OMP (Oh My Pi) model routing and policy";

  config = lib.mkIf cfg.enable {
    home.file = {
      ".omp/agent/RULES.md" = {
        source = ./RULES.md;
        force = true;
      };
    };

    # Keep config.yml and models.yml mutable because OMP updates them at runtime.
    # Merge the managed routing blocks and provider catalog while preserving unrelated
    # top-level keys. Provider credentials remain outside the Nix store via Keychain.
    home.activation.ompConfig = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
      if [ -z "''${DRY_RUN:-}" ]; then
        ${python}/bin/python ${./merge-config.py} "${ompAgentHome}"
      else
        echo "Would merge OMP configuration into ${ompAgentHome}/config.yml and ${ompAgentHome}/models.yml"
      fi
    '';
  };
}
