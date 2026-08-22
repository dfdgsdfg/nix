{ config, lib, pkgs, ... }:

let
  cfg = config.modules.claude;
  claudeHome = "${config.home.homeDirectory}/.claude";
in
{
  options.modules.claude.enable = lib.mkEnableOption "Claude Code subagent routing and policy configuration";

  config = lib.mkIf cfg.enable {
    home.file = {
      ".claude/CLAUDE.md" = {
        source = ./CLAUDE.md;
        force = true;
      };
      ".claude/agents/worker.md" = {
        source = ./agents/worker.md;
        force = true;
      };
      ".claude/agents/explorer.md" = {
        source = ./agents/explorer.md;
        force = true;
      };
      ".claude/agents/verifier.md" = {
        source = ./agents/verifier.md;
        force = true;
      };
      ".claude/agents/hard-worker.md" = {
        source = ./agents/hard-worker.md;
        force = true;
      };
      ".claude/agents/hard-reasoner.md" = {
        source = ./agents/hard-reasoner.md;
        force = true;
      };
      ".claude/agents/powerhouse.md" = {
        source = ./agents/powerhouse.md;
        force = true;
      };
    };

    # Keep settings.json mutable because Claude Code also records app-managed
    # hooks, statusLine, plugins, permissions, and session state there.
    # Only merge the policy keys owned here.
    home.activation.claudeSettings = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
      if [ -z "''${DRY_RUN:-}" ]; then
        ${pkgs.python3}/bin/python ${./merge-settings.py} "${claudeHome}/settings.json"
      else
        echo "Would merge Claude model and effort defaults into ${claudeHome}/settings.json"
      fi
    '';
  };
}
