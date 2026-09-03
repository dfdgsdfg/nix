{ config, inputs, lib, pkgs, ... }:

let
  upstreamBinaries = import ../../packages/upstream-binaries.nix { inherit lib pkgs; };
  localSend = upstreamBinaries.localsend;
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
    exec ${localSend}/bin/localsend "$@"
  '';
  zenPackages = import inputs.zen-browser {
    inherit pkgs;
  };
  rustdesk =
    let
      pname = "rustdesk";
      version = "1.4.9";
      src = pkgs.fetchurl {
        url = "https://github.com/rustdesk/rustdesk/releases/download/${version}/rustdesk-${version}-x86_64.AppImage";
        hash = "sha256-eQLNYKTymBfuviZooVyaGVKsaQ6Pewe/52IP7dTighc=";
      };
      appimageContents = pkgs.appimageTools.extract {
        inherit pname version src;
      };
    in
    pkgs.appimageTools.wrapType2 {
      inherit pname version src;

      extraInstallCommands = ''
        install -Dm444 ${appimageContents}/rustdesk.desktop \
          $out/share/applications/rustdesk.desktop
        substituteInPlace $out/share/applications/rustdesk.desktop \
          --replace-fail 'Exec=usr/share/rustdesk/rustdesk' \
          "Exec=$out/bin/rustdesk"
        cp -R ${appimageContents}/usr/share/icons $out/share/
        chmod u+w $out/share/icons/hicolor
        rm -f $out/share/icons/hicolor/icon-theme.cache
      '';

      meta = {
        description = "Open source remote desktop client";
        homepage = "https://rustdesk.com/";
        license = lib.licenses.agpl3Only;
        mainProgram = "rustdesk";
        platforms = [ "x86_64-linux" ];
        sourceProvenance = with lib.sourceTypes; [ binaryNativeCode ];
      };
    };
  orca =
    let
      pname = "orca";
      version = "1.4.196";
      src = pkgs.fetchurl {
        url = "https://github.com/stablyai/orca/releases/download/v${version}/orca-linux.AppImage";
        hash = "sha256-mrtZUBCvuokitKnpL6uZgn7kPpfB4UrL9qbCc4qp4S4=";
      };
      appimageContents = pkgs.appimageTools.extract {
        inherit pname version src;
      };
    in
    pkgs.appimageTools.wrapType2 {
      inherit pname version src;
      nativeBuildInputs = [ pkgs.makeWrapper ];

      extraInstallCommands = ''
        install -Dm444 ${appimageContents}/orca-ide.desktop \
          $out/share/applications/orca-ide.desktop
        substituteInPlace $out/share/applications/orca-ide.desktop \
          --replace-fail 'Exec=AppRun' "Exec=$out/bin/orca-ui"
        cp -R ${appimageContents}/usr/share/icons $out/share/
        chmod u+w $out/share/icons/hicolor
        rm -f $out/share/icons/hicolor/icon-theme.cache
        makeWrapper $out/bin/orca $out/bin/orca-ui \
          --add-flags '--ozone-platform=x11' \
          --add-flags '--force-prefers-reduced-motion'
      '';

      meta = {
        description = "IDE for parallel agentic development";
        homepage = "https://github.com/stablyai/orca";
        license = lib.licenses.mit;
        mainProgram = "orca";
        platforms = [ "x86_64-linux" ];
        sourceProvenance = with lib.sourceTypes; [ binaryNativeCode ];
      };
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
   telegram-desktop
   upstreamBinaries.zed
   bitwarden-desktop
   obsidian
   zoom-us
   rustdesk
   localSend
   localSendWithPort
   orca
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
  programs.ghostty.enable = true;

  programs.zen-browser = {
    enable = true;
    unwrappedPackage = zenPackages.beta-unwrapped;
  };
}
