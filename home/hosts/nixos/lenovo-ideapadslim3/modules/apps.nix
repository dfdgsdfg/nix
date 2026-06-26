{ config, inputs, lib, pkgs, ... }:

let
  localSendPort = 53317;
  setLocalSendPort = pkgs.writeShellScript "set-localsend-port" ''
    prefs="''${XDG_DATA_HOME:-$HOME/.local/share}/org.localsend.localsend_app/shared_preferences.json"
    ${pkgs.coreutils}/bin/mkdir -p "$(${pkgs.coreutils}/bin/dirname "$prefs")"

    tmp="$(${pkgs.coreutils}/bin/mktemp)"
    if [ -s "$prefs" ] && ${pkgs.jq}/bin/jq empty "$prefs" >/dev/null 2>&1; then
      ${pkgs.jq}/bin/jq '. + {"flutter.ls_port": ${toString localSendPort}}' "$prefs" > "$tmp"
    else
      ${pkgs.jq}/bin/jq -n '{"flutter.ls_port": ${toString localSendPort}}' > "$tmp"
    fi

    ${pkgs.coreutils}/bin/chmod 600 "$tmp"
    ${pkgs.coreutils}/bin/mv "$tmp" "$prefs"
  '';
  localSendWithPort = pkgs.writeShellScriptBin "localsend-fixed-port" ''
    ${setLocalSendPort}
    exec ${pkgs.localsend}/bin/localsend_app "$@"
  '';
  zenPackages = import inputs.zen-browser {
    inherit pkgs;
  };
in
{
  imports = [
    inputs.zen-browser.homeModules.beta
  ];

  # List packages installed in system profile. To search, run:
  # $ nix search wget
  home.packages = with pkgs; [
   #vim # Do not forget to add an editor to edit configuration.nix! The Nano editor is also installed by>
   #wget
   vscode
   discord-ptb
   slack
   zed-editor
   bitwarden-desktop
   zoom-us
   localsend
   localSendWithPort
   inputs.seance.packages.${pkgs.stdenv.hostPlatform.system}.seance
  ];

  home.activation.setLocalSendPort = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    ${setLocalSendPort}
  '';

  xdg.desktopEntries.LocalSend = {
    name = "LocalSend";
    genericName = "An open source cross-platform alternative to AirDrop";
    exec = "${localSendWithPort}/bin/localsend-fixed-port %U";
    icon = "localsend";
    categories = [ "GTK" "FileTransfer" "Utility" ];
    startupNotify = true;
    settings.StartupWMClass = "localsend_app";
  };

  programs.firefox.enable = true;

  programs.zen-browser = {
    enable = true;
    unwrappedPackage = zenPackages.beta-unwrapped;
  };
}
