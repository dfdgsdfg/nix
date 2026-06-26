{ pkgs, ... }:

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
    "org/gnome/shell" = {
      enabled-extensions = [
        autoMoveWindowsUuid
      ];
      disabled-extensions = [ ];
    };

    "org/gnome/shell/extensions/auto-move-windows" = {
      application-list = [
        "com.seance.app.desktop:2"
        "zen-beta.desktop:3"
        "discord-ptb.desktop:4"
      ];
    };
  };
}
