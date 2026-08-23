{ lib, pkgs, ... }:

let
  autoMoveWindowsUuid = "auto-move-windows@gnome-shell-extensions.gcampax.github.com";
in
{
  home.packages = with pkgs; [
    gnomeExtensions.auto-move-windows
  ];

  home.file.".local/share/gnome-shell/extensions/${autoMoveWindowsUuid}".source =
    "${pkgs.gnomeExtensions.auto-move-windows}/share/gnome-shell/extensions/${autoMoveWindowsUuid}";

  dconf.settings = {
    "org/gnome/desktop/session" = {
      idle-delay = lib.hm.gvariant.mkUint32 0;
    };

    # Keep the session available to GNOME Remote Desktop when the display
    # blanks. Explicit locking (for example, Super+L) still remains available.
    "org/gnome/desktop/screensaver" = {
      lock-enabled = false;
    };

    "org/gnome/shell" = {
      enabled-extensions = [
        autoMoveWindowsUuid
      ];
      disabled-extensions = [ ];
    };

    "org/gnome/shell/extensions/auto-move-windows" = {
      application-list = [
        "com.mitchellh.ghostty.desktop:2"
        "orca-ide.desktop:2"
        "zen-beta.desktop:3"
        "discord-ptb.desktop:4"
      ];
    };

    # Keep GNOME from suspending while on AC power. Battery behavior is left
    # unchanged, so the existing battery suspend policy still applies.
    "org/gnome/settings-daemon/plugins/power" = {
      sleep-inactive-ac-type = "nothing";
    };
  };
}
