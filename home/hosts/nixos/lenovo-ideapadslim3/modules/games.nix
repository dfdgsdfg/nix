{ config, lib, pkgs, ... }:

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
    heroic
    (retroarch.withCores (cores: with cores; [
      genesis-plus-gx
      snes9x
      beetle-psx-hw
    ]))
  ];
  # nixpkgs.overlays = [
  #   (final: prev: {
  #     retroarch-bare = prev.retroarch-bare.overrideAttrs (old: {
  #       patches = (old.patches or [ ]) ++ [
  #         (final.fetchpatch {
  #           url = "https://github.com/libretro/RetroArch/commit/2bc0a25e6f5cf2b67b183792886e24c2ec5d448e.patch";
  #           sha256 = "sha256-gkpBql5w/xUpddv/6sePb5kZ5gy9huStDthmvoz6Qbk=";
  #         })
  #       ];
  #     });
  #   })
  # ];
  # programs.gamescope.enable = true;
  # programs.gamemode.enable = true;
}
