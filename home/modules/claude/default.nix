{ config, inputs, lib, pkgs, ... }:

let
  cfg = config.modules.claude;
  claudeHome = "${config.home.homeDirectory}/.claude";
in
{
  options.modules.claude.enable = lib.mkEnableOption "Claude Code subagent routing and policy configuration";

  config = lib.mkIf cfg.enable {
    home.packages = lib.optionals (!pkgs.stdenv.hostPlatform.isDarwin) [
      inputs.claude-code-nix.packages.${pkgs.stdenv.hostPlatform.system}.claude-code
    ];

    home.file = {
      ".claude/CLAUDE.md" = {
        source = ./CLAUDE.md;
        force = true;
      };
      ".claude/agents/scout.md" = {
        source = ./agents/scout.md;
        force = true;
      };
      ".claude/agents/Explore.md" = {
        source = ./agents/Explore.md;
        force = true;
      };
      ".claude/agents/general-purpose.md" = {
        source = ./agents/general-purpose.md;
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
