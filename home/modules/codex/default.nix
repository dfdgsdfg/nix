{ config, lib, pkgs, ... }:

let
  cfg = config.modules.codex;
  codexHome = "${config.home.homeDirectory}/.codex";
  toml = pkgs.formats.toml { };
  upstreamBinaries = import ../../packages/upstream-binaries.nix { inherit lib pkgs; };
  roleNames = [
    "worker"
    "explorer"
    "scout"
    "powerhouse"
  ];
  roleConfigs = lib.genAttrs roleNames (
    name: builtins.fromTOML (builtins.readFile (./agents + "/${name}.toml"))
  );
  apiRoleConfigs = lib.mapAttrs (
    _name: role:
    role
    // {
      model = "model/${role.model}";
      model_provider = "omniroute";
    }
  ) roleConfigs;
  apiRoleFiles = lib.mapAttrs (
    name: role: toml.generate "codex-api-agent-${name}.toml" role
  ) apiRoleConfigs;
  codexBin = if pkgs.stdenv.hostPlatform.isDarwin then
    (if pkgs.stdenv.hostPlatform.isAarch64 then "/opt/homebrew/bin/codex" else "/usr/local/bin/codex")
    else "${upstreamBinaries.codex}/bin/codex";
  platform = if pkgs.stdenv.hostPlatform.isDarwin then "darwin" else "linux";
  keychainAuth = pkgs.writeShellScriptBin "codex-omniroute-auth" ''
    exec ${pkgs.python3}/bin/python ${./keychain-auth.py} "$@"
  '';
  sopsKeyPath = config.sops.secrets."personal-codex".path;
  authArgs =
    [
      "--platform"
      platform
      "--account"
      config.home.username
      "--sops-file"
      sopsKeyPath
    ]
    ++ lib.optionals pkgs.stdenv.hostPlatform.isDarwin [
      "--security"
      "/usr/bin/security"
    ]
    ++ lib.optionals pkgs.stdenv.hostPlatform.isLinux [
      "--secret-tool"
      "${pkgs.libsecret}/bin/secret-tool"
    ];
  apiConfig = toml.generate "codex-omni-api.config.toml" {
    model = "model/gpt-6-astra";
    model_provider = "omniroute";
    model_catalog_json = "${codexHome}/api-models.json";
    model_reasoning_effort = "medium";
    agents = {
      default_subagent_model = "model/gpt-5.6-luna";
    }
    // lib.genAttrs roleNames (
      name: {
        description = roleConfigs.${name}.description;
        config_file = "${codexHome}/api-agents/${name}.toml";
      }
    );
    model_providers.omniroute = {
      name = "OmniRoute";
      base_url = "https://omni.tail484abe.ts.net/v1";
      wire_api = "responses";
      requires_openai_auth = false;
      supports_websockets = false;
      auth = {
        command = "${keychainAuth}/bin/codex-omniroute-auth";
        args = authArgs;
        timeout_ms = 30000;
      };
    };
  };
in
{
  options.modules.codex.enable = lib.mkEnableOption "Codex multi-model agent routing";

  config = lib.mkIf cfg.enable {
    sops.secrets."personal-codex" = {
      format = "yaml";
      sopsFile = ../../../secrets/codex.yaml;
      key = "personal-codex";
      path = "${config.xdg.configHome}/omniroute/personal-codex.key";
      mode = "0400";
    };

    home.packages = lib.optionals (!pkgs.stdenv.hostPlatform.isDarwin) [ upstreamBinaries.codex ];

    home.file =
      {
        ".codex/AGENTS.md" = {
          source = ./AGENTS.md;
          force = true;
        };
        ".codex/agents/worker.toml" = {
          source = ./agents/worker.toml;
          force = true;
        };
        ".codex/agents/explorer.toml" = {
          source = ./agents/explorer.toml;
          force = true;
        };
        ".codex/agents/scout.toml" = {
          source = ./agents/scout.toml;
          force = true;
        };
        ".codex/agents/powerhouse.toml" = {
          source = ./agents/powerhouse.toml;
          force = true;
        };
      }
      // (lib.mapAttrs'
        (
          name: source:
          lib.nameValuePair ".codex/api-agents/${name}.toml" {
            inherit source;
            force = true;
          }
        )
        apiRoleFiles)
      // { ".codex/omni-api-template.toml".source = apiConfig; };

    home.activation.codexApiProfile = lib.hm.dag.entryAfter [ "linkGeneration" ] ''
      if [ -z "''${DRY_RUN:-}" ]; then
        ${pkgs.python3}/bin/python ${./build-api-catalog.py} ${codexBin} "${codexHome}/api-models.json"
        ${pkgs.python3}/bin/python ${./sync-api-profile.py} ${apiConfig} ${./merge-config.py}
      fi
    '';

    # Keep config.toml mutable because Codex also records app-managed plugin,
    # MCP, notice, and project state there. Only merge the keys owned here.
    home.activation.codexConfig = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
      if [ -z "''${DRY_RUN:-}" ]; then
        ${pkgs.python3}/bin/python ${./merge-config.py} "${codexHome}/config.toml"
      else
        echo "Would merge Codex model and subagent defaults into ${codexHome}/config.toml"
      fi
    '';
  };
}
