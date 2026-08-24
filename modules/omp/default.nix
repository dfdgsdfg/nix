{ config, lib, pkgs, ... }:

let
  cfg = config.modules.omp;
  system = pkgs.stdenv.hostPlatform.system;
  ompAgentHome = "${config.home.homeDirectory}/.omp/agent";
  python = pkgs.python3.withPackages (pythonPackages: [ pythonPackages.pyyaml ]);
  release = {
    x86_64-linux = {
      asset = "omp-linux-x64";
      hash = "sha256-RzNmIGK/tDZOSrOH15QOVqcUPl3BwgcmeH5huxtS3yg=";
    };
    aarch64-darwin = {
      asset = "omp-darwin-arm64";
      hash = "sha256-MU6EoE4Ug5qSkctwTJjnR8af7+LsQ+fGp0qeKTsfGLk=";
    };
  }.${system} or (throw "OMP is not packaged for ${system}");
  omp = pkgs.stdenvNoCC.mkDerivation rec {
    pname = "omp";
    version = "18.0.3";

    src = pkgs.fetchurl {
      url = "https://github.com/can1357/oh-my-pi/releases/download/v${version}/${release.asset}";
      inherit (release) hash;
    };

    dontUnpack = true;
    nativeBuildInputs = lib.optionals pkgs.stdenv.hostPlatform.isLinux [ pkgs.makeWrapper ];

    installPhase = if pkgs.stdenv.hostPlatform.isLinux then ''
      runHook preInstall
      install -Dm755 "$src" "$out/libexec/omp"
      makeWrapper ${pkgs.stdenv.cc.bintools.dynamicLinker} "$out/bin/omp" \
        --add-flags "$out/libexec/omp"
      runHook postInstall
    '' else ''
      runHook preInstall
      install -Dm755 "$src" "$out/bin/omp"
      runHook postInstall
    '';

    meta = {
      description = "AI coding agent for the terminal";
      homepage = "https://omp.sh/";
      license = lib.licenses.mit;
      mainProgram = "omp";
      platforms = [ "x86_64-linux" "aarch64-darwin" ];
    };
  };
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
    home.packages = [ omp ];

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
