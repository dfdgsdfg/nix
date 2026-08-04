{ config, inputs, lib, pkgs, ... }:

let
  localSendPort = 53317;
  orcaServePort = 6768;
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
  orca =
    let
      pname = "orca";
      version = "1.4.167";
      src = pkgs.fetchurl {
        url = "https://github.com/stablyai/orca/releases/download/v${version}/orca-linux.AppImage";
        hash = "sha256-gTsR6Z98qkv45PxHIA3WxGXzSgTWHoVa29iCIZBZLjM=";
      };
      appimageContents = pkgs.appimageTools.extractType2 {
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
          --replace-fail 'Exec=AppRun' "Exec=$out/bin/orca"
        cp -R ${appimageContents}/usr/share/icons $out/share/
        wrapProgram $out/bin/orca \
          --add-flags '--ozone-platform=x11'
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
  orcaServe = pkgs.writeShellApplication {
    name = "orca-serve";
    runtimeInputs = [
      pkgs.tailscale
      pkgs.xorg-server
    ];
    text = ''
      if ! pairingAddress="$(${pkgs.tailscale}/bin/tailscale ip -4)"; then
        echo "Waiting for a Tailscale IPv4 address" >&2
        exit 1
      fi
      if [ -z "$pairingAddress" ]; then
        echo "Tailscale did not return an IPv4 address" >&2
        exit 1
      fi

      export LIBGL_ALWAYS_SOFTWARE=1
      export XDG_CONFIG_HOME="''${XDG_CONFIG_HOME:-$HOME/.config}/orca-serve"
      ${pkgs.coreutils}/bin/mkdir -p "$XDG_CONFIG_HOME"

      exec ${orca}/bin/orca serve \
        --port ${toString orcaServePort} \
        --pairing-address "$pairingAddress" \
        --json
    '';
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
   rustdesk
   localsend
   localSendWithPort
   orca
   inputs.seance.packages.${pkgs.stdenv.hostPlatform.system}.seance
  ];

  home.activation.setLocalSendPort = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    ${setLocalSendPort}
  '';

  systemd.user.services.orca-serve = {
    Unit = {
      Description = "Orca headless runtime server";
      StartLimitIntervalSec = 300;
      StartLimitBurst = 5;
    };
    Service = {
      Type = "simple";
      ExecStart = "${orcaServe}/bin/orca-serve";
      WorkingDirectory = "%h";
      UMask = "0077";
      Restart = "on-failure";
      RestartPreventExitStatus = 3;
      RestartSec = "5s";
    };
    Install.WantedBy = [ "default.target" ];
  };

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
