{ config, lib, pkgs, ... }:

let
  myNode = pkgs.nodejs_24;

  pnpm-shim = pkgs.writeShellScriptBin "pnpm" ''
    exec "${pkgs.lib.getBin myNode}/bin/node" "${pkgs.lib.getBin myNode}/bin/corepack" pnpm "$@"
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
    myNode
    pnpm-shim
  ];

  home.sessionVariables = {
    COREPACK_HOME = "$HOME/.cache/corepack";
    PNPM_HOME = "HOME/.local/share/pnpm";
  };

  home.sessionPath = [
    "$HOME/.local/share/pnpm"
    "$HOME/.local/share/pnpm/bin"
  ];

  programs.fish.shellInit = ''
    set -gx COREPACK_HOME "$HOME/.cache/corepack"
    set -gx PNPM_HOME "$HOME/.local/share/pnpm"

    fish_add_path "$HOME/.local/share/pnpm"
    fish_add_path "$HOME/.local/share/pnpm/bin"
  '';

  programs.mise = {
    enable = true;
    enableFishIntegration = true;
  };

  programs.direnv = {
    enable = true;
    enableFishIntegration = true;
    nix-direnv.enable = true;
  };
}
