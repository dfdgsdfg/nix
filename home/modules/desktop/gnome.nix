{ lib, pkgs, ... }:

let
  autoMoveWindowsUuid = "auto-move-windows@gnome-shell-extensions.gcampax.github.com";
  autoMoveWindows = pkgs.gnomeExtensions.auto-move-windows.overrideAttrs (_: rec {
    version = "75";
    src = pkgs.fetchzip {
      url = "https://extensions.gnome.org/extension-data/auto-move-windowsgnome-shell-extensions.gcampax.github.com.v${version}.shell-extension.zip";
      hash = "sha256-DmoGh9ypAO5x46YsnJg4fngKawuIto6mtVMnUJNXQlY=";
      stripRoot = false;
    };
  });
in
{
  home.packages = [
    autoMoveWindows
  ];

  home.file.".local/share/gnome-shell/extensions/${autoMoveWindowsUuid}".source =
    "${autoMoveWindows}/share/gnome-shell/extensions/${autoMoveWindowsUuid}";

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
        "obsidian.desktop:1"
        "com.mitchellh.ghostty.desktop:2"
        "orca-ide.desktop:2"
        "zen-beta.desktop:3"
        "discord-ptb.desktop:4"
        "org.telegram.desktop.desktop:4"
      ];
    };

    # Keep GNOME from suspending while on AC power. Battery behavior is left
    # unchanged, so the existing battery suspend policy still applies.
    "org/gnome/settings-daemon/plugins/power" = {
      sleep-inactive-ac-type = "nothing";
    };
  };
}
