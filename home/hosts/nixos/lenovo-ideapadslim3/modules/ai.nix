{ config, lib, pkgs, pkgsUnstable, inputs, ... }:

let
  system = pkgs.stdenv.hostPlatform.system;
  omp = pkgs.stdenvNoCC.mkDerivation rec {
    pname = "omp";
    version = "18.0.3";

    src = pkgs.fetchurl {
      url = "https://github.com/can1357/oh-my-pi/releases/download/v${version}/omp-linux-x64";
      hash = "sha256-RzNmIGK/tDZOSrOH15QOVqcUPl3BwgcmeH5huxtS3yg=";
    };

    dontUnpack = true;
    nativeBuildInputs = [ pkgs.makeWrapper ];

    installPhase = ''
      runHook preInstall
      install -Dm755 "$src" "$out/libexec/omp"
      makeWrapper ${pkgs.stdenv.cc.bintools.dynamicLinker} "$out/bin/omp" \
        --add-flags "$out/libexec/omp"
      runHook postInstall
    '';

    meta = {
      description = "AI coding agent for the terminal";
      homepage = "https://omp.sh/";
      license = lib.licenses.mit;
      mainProgram = "omp";
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

    inputs.codex-cli-nix.packages.${system}.codex
    libsecret
    pkgsUnstable.pi-coding-agent
    omp
  ];

  programs.claude-code = {
    enable = true;
    package = inputs.claude-code-nix.packages.${system}.claude-code;
  };
}
