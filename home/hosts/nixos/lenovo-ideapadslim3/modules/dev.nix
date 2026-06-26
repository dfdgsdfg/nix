{ config, lib, pkgs, ... }:

let
  myNode = pkgs.nodejs_24;
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

  pnpm-shim = pkgs.writeShellScriptBin "pnpm" ''
    exec "${pkgs.lib.getBin myNode}/bin/node" "${pkgs.lib.getBin myNode}/bin/corepack" pnpm "$@"
  '';
  pnpx-shim = pkgs.writeShellScriptBin "pnpx" ''
    exec "${pkgs.pnpm}/bin/pnpx" "$@"
  '';
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
    myNode
    pnpm-shim
    pnpx-shim
  ];

  home.sessionVariables = {
    ANDROID_HOME = androidSdkRoot;
    ANDROID_SDK_ROOT = androidSdkRoot;
    COREPACK_HOME = "$HOME/.cache/corepack";
    PNPM_HOME = "$HOME/.local/share/pnpm";
  };

  home.sessionPath = [
    "${androidSdkRoot}/platform-tools"
    "${androidSdkRoot}/cmdline-tools/latest/bin"
    "$HOME/.local/share/pnpm"
    "$HOME/.local/share/pnpm/bin"
  ];

  programs.fish.shellInit = ''
    set -gx ANDROID_HOME "${androidSdkRoot}"
    set -gx ANDROID_SDK_ROOT "${androidSdkRoot}"
    set -gx COREPACK_HOME "$HOME/.cache/corepack"
    set -gx PNPM_HOME "$HOME/.local/share/pnpm"

    fish_add_path "${androidSdkRoot}/platform-tools"
    fish_add_path "${androidSdkRoot}/cmdline-tools/latest/bin"
    fish_add_path "$HOME/.local/share/pnpm"
    fish_add_path "$HOME/.local/share/pnpm/bin"
  '';

  programs.mise = {
    enable = true;
    enableFishIntegration = true;
    globalConfig.tools = {
      node = "lts";
      python = "miniconda3-latest";
      deno = "latest";
      java = "zulu-25";
      ruby = "latest";
      go = "latest";
      bun = "latest";
      erlang = "latest";
      zig = "latest";
      uv = "latest";
      fnox = "latest";
    };
  };

  programs.direnv = {
    enable = true;
    enableFishIntegration = true;
    nix-direnv.enable = true;
  };
}
