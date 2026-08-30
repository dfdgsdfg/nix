{ config, lib, pkgs, pkgsUnstable, ... }:

let
  cfg = config.modules.pi;
  piHome = "${config.home.homeDirectory}/.pi";
  piVersion = "0.84.4";
  piSrc = pkgsUnstable.fetchFromGitHub {
    owner = "earendil-works";
    repo = "pi";
    tag = "v${piVersion}";
    hash = "sha256-7z8OXao1PzmBEepDkIqVqyfQBPHulBlKcGymDYsnMvc=";
  };
  piCodingAgent = pkgsUnstable.pi-coding-agent.overrideAttrs (_finalAttrs: _oldAttrs: {
    version = piVersion;
    src = piSrc;
    npmDeps = pkgsUnstable.fetchNpmDeps {
      src = piSrc;
      hash = "sha256-35GC3Q4Jf4URvqoEYHeM63x49tTmrth62//PvKm4I7Q=";
    };
    modelData = pkgsUnstable.fetchurl {
      url = "https://registry.npmjs.org/@earendil-works/pi-ai/-/pi-ai-${piVersion}.tgz";
      hash = "sha256-39PJKc7lpzhxmaCiTfwb4glvHqj1n/uChRmKDtAev5M=";
    };
  });
in
{
  options.modules.pi.enable = lib.mkEnableOption "Pi multi-model agent routing and configuration";

  config = lib.mkIf cfg.enable {
    home.packages = [ piCodingAgent ];

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
