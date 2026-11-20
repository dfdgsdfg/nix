{
  config,
  lib,
  pkgs,
  ...
}:

let
  cfg = config.modules.omp;
  system = pkgs.stdenv.hostPlatform.system;
  ompAgentHome = "${config.home.homeDirectory}/.omp/agent";
  python = pkgs.python3.withPackages (pythonPackages: [ pythonPackages.pyyaml ]);
  release =
    {
      x86_64-linux = {
        asset = "omp-linux-x64";
        hash = "sha256-9waye6hFg02Pg2BwWi6boVNPNZP6JEEdQTWCct4zZCs=";
      };
      aarch64-darwin = {
        asset = "omp-darwin-arm64";
        hash = "sha256-0YURPWProjkl5dcKtmGkJLgnwGyY+Odmw79K1i3a/5o=";
      };
    }
    .${system} or (throw "OMP is not packaged for ${system}");
  omp = pkgs.stdenvNoCC.mkDerivation rec {
    pname = "omp";
    version = "18.22.0";

    src = pkgs.fetchurl {
      url = "https://github.com/can1357/oh-my-pi/releases/download/v${version}/${release.asset}";
      inherit (release) hash;
    };

    dontUnpack = true;
    nativeBuildInputs = lib.optionals pkgs.stdenv.hostPlatform.isLinux [ pkgs.patchelf ];

    installPhase =
      if pkgs.stdenv.hostPlatform.isLinux then
        ''
          runHook preInstall
          install -Dm755 "$src" "$out/bin/omp"
          # A loader wrapper makes Bun's process.execPath point at ld-linux.
          # OMP re-executes that path for command-backed credentials and native
          # helpers, so patch the ELF interpreter and keep the executable real.
          patchelf --set-interpreter ${pkgs.stdenv.cc.bintools.dynamicLinker} "$out/bin/omp"
          runHook postInstall
        ''
      else
        ''
          runHook preInstall
          install -Dm755 "$src" "$out/bin/omp"
          runHook postInstall
        '';

    doInstallCheck = pkgs.stdenv.hostPlatform.isLinux
      && pkgs.stdenv.buildPlatform.canExecute pkgs.stdenv.hostPlatform;
    installCheckPhase = ''
      runHook preInstallCheck
      "$out/bin/omp" --version
      BUN_BE_BUN=1 "$out/bin/omp" -e '
        const child = Bun.spawnSync([process.execPath, "-e", "process.stdout.write(\"runtime-ok\")"], {
          env: { ...process.env, BUN_BE_BUN: "1" }, stdout: "pipe"
        });
        if (child.exitCode !== 0 || new TextDecoder().decode(child.stdout) !== "runtime-ok") process.exit(1);
      '
      runHook postInstallCheck
    '';

    meta = {
      description = "AI coding agent for the terminal";
      homepage = "https://omp.sh/";
      license = lib.licenses.mit;
      mainProgram = "omp";
      sourceProvenance = with lib.sourceTypes; [ binaryNativeCode ];
      platforms = [
        "x86_64-linux"
        "aarch64-darwin"
      ];
    };
  };
in
{
  options.modules.omp = {
    enable = lib.mkEnableOption "OMP (Oh My Pi) model routing and policy";

    apiKeyCommand = lib.mkOption {
      type = lib.types.str;
      default = ''!security find-generic-password -a "$USER" -s "omniroute-personal-omp" -w'';
      description = "Command OMP executes to read its OmniRoute client key from the platform secret store.";
    };
  };

  config = lib.mkIf cfg.enable {
    home.packages = lib.optionals (!pkgs.stdenv.hostPlatform.isDarwin) [ omp ];

    home.file = {
      ".omp/agent/RULES.md" = {
        source = ./RULES.md;
        force = true;
      };
      ".omp/agent/agents/scout.md" = {
        source = ./scout.md;
        force = true;
      };
      ".omp/agent/agents/explorer.md" = {
        source = ./explorer.md;
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
