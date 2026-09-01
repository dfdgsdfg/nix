{ config, lib, pkgs, ... }:

let
  pathOrder = import ../../path-order.nix;
  androidEnv = pkgs.androidenv.override {
    licenseAccepted = true;
  };
  androidComposition = androidEnv.composeAndroidPackages {
    platformVersions = [ "35" ];
    buildToolsVersions = [ "35.0.0" ];
    includeCmake = false;
    includeEmulator = false;
    includeNDK = false;
    includeSystemImages = false;
  };
  androidSdk = androidComposition.androidsdk;
  androidSdkRoot = "${androidSdk}/libexec/android-sdk";

  xtool = let
    pname = "xtool";
    version = "1.17.0";
    src = pkgs.fetchurl {
      url = "https://github.com/xtool-org/xtool/releases/download/${version}/xtool-x86_64.AppImage";
      hash = "sha256-dWbWK4KaTerbAbU4nJT0V2PYUfIExdIvo26fnRyI1Xs=";
    };
    appimageContents = pkgs.appimageTools.extract {
      inherit pname version src;
    };
  in pkgs.appimageTools.wrapType2 {
    inherit pname version src;

    extraInstallCommands = ''
      install -Dm444 ${appimageContents}/xtool.desktop $out/share/applications/xtool.desktop
      install -Dm444 ${appimageContents}/xtool.png $out/share/icons/hicolor/256x256/apps/xtool.png
    '';

    meta = {
      description = "Cross-platform Xcode replacement for building and deploying iOS apps with SwiftPM";
      homepage = "https://xtool.sh/";
      license = lib.licenses.mit;
      mainProgram = "xtool";
      platforms = [ "x86_64-linux" ];
      sourceProvenance = with lib.sourceTypes; [ binaryNativeCode ];
    };
  };
in
{
  # The home.packages option allows you to install Nix packages into your
  # environment.
  home.packages = with pkgs; [
    # # Adds the 'hello' command to your environment. It prints a friendly
    # # "Hello, world!" when run.
    # pkgs.hello

    # # It is sometimes useful to fine-tune packages, for example, by applying
    # # overrides. You can do that directly here, just don't forget the
    # # parentheses. Maybe you want to install Nerd Fonts with a limited number of
    # # fonts?
    # (pkgs.nerdfonts.override { fonts = [ "FantasqueSansMono" ]; })

    # # You can also create simple shell scripts directly inside your
    # # configuration. For example, this adds a command 'my-hello' to your
    # # environment:
    # (pkgs.writeShellScriptBin "my-hello" ''
    #   echo "Hello, ${config.home.username}!"
    # '')

    # devenv
    androidSdk
    libimobiledevice
    usbmuxd
    xtool
  ];

  home.sessionVariables = {
    ANDROID_HOME = androidSdkRoot;
    ANDROID_SDK_ROOT = androidSdkRoot;
  };

  home.sessionPath = lib.mkOrder pathOrder.sdk [
    "${androidSdkRoot}/platform-tools"
    "${androidSdkRoot}/cmdline-tools/latest/bin"
  ];

  programs.fish.shellInit = ''
    set -gx ANDROID_HOME "${androidSdkRoot}"
    set -gx ANDROID_SDK_ROOT "${androidSdkRoot}"
  '';

  programs.direnv = {
    enable = true;
    enableFishIntegration = true;
    nix-direnv.enable = true;
  };
}
