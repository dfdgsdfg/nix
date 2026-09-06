{ config, lib, pkgs, pkgsUnstable, ... }:

let
  cfg = config.modules.pi;
  piHome = "${config.home.homeDirectory}/.pi";
  pnpmHome = "${config.home.homeDirectory}/Library/pnpm";
  brewPrefix = if pkgs.stdenv.hostPlatform.isAarch64 then "/opt/homebrew" else "/usr/local";
  piVersion = "0.85.1";
  piSrc = pkgsUnstable.fetchFromGitHub {
    owner = "earendil-works";
    repo = "pi";
    tag = "v${piVersion}";
    hash = "sha256-gU8BSiqqOYt2RRuQONHHGvZeSM5KFQVrwif9bmuUXUc=";
  };
  piCodingAgent = pkgsUnstable.pi-coding-agent.overrideAttrs (_finalAttrs: oldAttrs: {
    version = piVersion;
    src = piSrc;
    npmDeps = pkgsUnstable.fetchNpmDeps {
      src = piSrc;
      hash = "sha256-jzlsZIQzfl1FCZZ5//dHFWwMfBZQ4nRD6KB4HHifPqE=";
    };
    modelData = pkgsUnstable.fetchurl {
      url = "https://registry.npmjs.org/@earendil-works/pi-ai/-/pi-ai-${piVersion}.tgz";
      hash = "sha256-r30RmGF5RFzm/oizfVfeIvgjwP/TplyuMcVVt/XpklM=";
    };
    preBuild = (oldAttrs.preBuild or "") + ''
      npx tsgo -p packages/chord/tsconfig.build.json
    '';
    postInstall = (oldAttrs.postInstall or "") + ''
      nm="$out/lib/node_modules/pi-monorepo/node_modules"
      mkdir -p "$nm/@earendil-works"
      cp -r packages/chord "$nm/@earendil-works/chord"
    '';
  });
in
{
  options.modules.pi.enable = lib.mkEnableOption "Pi multi-model agent routing and configuration";

  config = lib.mkIf cfg.enable {
    home.packages = lib.optionals (!pkgs.stdenv.hostPlatform.isDarwin) [ piCodingAgent ];

    home.activation.piPackage = lib.mkIf pkgs.stdenv.hostPlatform.isDarwin (
      lib.hm.dag.entryBetween [ "piConfig" ] [ "writeBoundary" ] ''
        if [ -z "''${DRY_RUN:-}" ]; then
          if [ ! -x "${pnpmHome}/bin/pi" ]; then
            if [ ! -x "${brewPrefix}/bin/mise" ]; then
              echo "mise must be installed by nix-darwin before installing Pi with pnpm" >&2
              exit 1
            fi

            export PNPM_HOME="${pnpmHome}"
            export PATH="$PNPM_HOME/bin:$PNPM_HOME:$PATH"
            ${brewPrefix}/bin/mise exec pnpm@latest -- \
              pnpm add --global --ignore-scripts @earendil-works/pi-coding-agent
          fi
        else
          echo "Would install Pi with pnpm when ${pnpmHome}/bin/pi is missing"
        fi
      ''
    );

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
