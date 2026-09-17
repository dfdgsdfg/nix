{ config, lib, pkgs, ... }:
let
  cfg = config.modules.desktop.connections;
  targets = pkgs.writeText "connections.json" (builtins.toJSON cfg.targets);
in
{
  options.modules.desktop.connections = {
    enable = lib.mkEnableOption "personal GNOME Connections bookmarks";
    targets = lib.mkOption {
      default = { };
      type = lib.types.attrsOf (lib.types.submodule ({ name, config, ... }: {
        options = {
          displayName = lib.mkOption { type = lib.types.str; default = name; };
          protocol = lib.mkOption { type = lib.types.enum [ "rdp" "vnc" ]; };
          host = lib.mkOption { type = lib.types.str; };
          port = lib.mkOption {
            type = lib.types.port;
            default = if config.protocol == "rdp" then 3389 else 5900;
          };
        };
      }));
      description = "Connection bookmarks; authentication remains in the GNOME keyring.";
    };
  };

  config = lib.mkIf cfg.enable {
    assertions = [ {
      assertion = pkgs.stdenv.hostPlatform.isLinux;
      message = "GNOME Connections bookmarks require Linux.";
    } ];
    home.packages = [ pkgs.gnome-connections ];
    home.activation.connectionsBookmarks = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
      if [ -z "''${DRY_RUN:-}" ]; then
        ${pkgs.python3}/bin/python ${./merge.py} \
          ${lib.escapeShellArg "${config.xdg.configHome}/connections.db"} ${targets}
      else
        echo "Would merge GNOME Connections bookmarks"
      fi
    '';
  };
}
