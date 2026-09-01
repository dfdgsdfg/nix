{ config, lib, pkgs, ... }:

let
  cfg = config.modules.codex;
  codexHome = "${config.home.homeDirectory}/.codex";
  upstreamBinaries = import ../../packages/upstream-binaries.nix { inherit lib pkgs; };
in
{
  options.modules.codex.enable = lib.mkEnableOption "Codex multi-model agent routing";

  config = lib.mkIf cfg.enable {
    home.packages = lib.optionals (!pkgs.stdenv.hostPlatform.isDarwin) [ upstreamBinaries.codex ];

    home.file = {
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
    };

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
