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
    noto-fonts
    noto-fonts-cjk-sans
    noto-fonts-color-emoji
    nerd-fonts.meslo-lg
  ];

  fonts.fontconfig.defaultFonts = {
    sansSerif = [ "Noto Sans CJK KR" "Noto Sans" "DejaVu Sans" ];
    serif = [ "Noto Serif CJK KR" "Noto Serif" "DejaVu Serif" ];
    monospace = [ "MesloLGM Nerd Font Mono" "Noto Sans Mono CJK KR" ];
    emoji = [ "Noto Color Emoji" ];
  };
}
