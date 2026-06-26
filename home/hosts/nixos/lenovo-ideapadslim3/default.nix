{ config, lib, pkgs, ... }:

let
  globalGitIgnores = [
    ".DS_Store"
    ".AppleDouble"
    ".LSOverride"
    "Icon"
    "._*"
    ".DocumentRevisions-V100"
    ".fseventsd"
    ".Spotlight-V100"
    ".TemporaryItems"
    ".Trashes"
    ".VolumeIcon.icns"
    ".AppleDB"
    ".AppleDesktop"
    "Network Trash Folder"
    "Temporary Items"
    ".apdisk"
    "Thumbs.db"
    "ehthumbs.db"
    "Desktop.ini"
    "$RECYCLE.BIN/"
    "*.cab"
    "*.msi"
    "*.msm"
    "*.msp"
    "*.lnk"
    "*~"
    ".directory"
    ".Trash-*"
    "[._]*.s[a-w][a-z]"
    "[._]s[a-w][a-z]"
    "*.un~"
    "Session.vim"
    ".netrwhist"
    "**/.claude/settings.local.json"
  ];
in

{
  imports = [
    ../../../../modules/ssh
    ./modules/fonts.nix
    ./modules/fish.nix
    ./modules/common.nix
    ./modules/ssh.nix
    ./modules/gnome.nix
    ./modules/neovim.nix
    ./modules/apps.nix
    ./modules/games.nix
    ./modules/music.nix
    ./modules/dev.nix
    ./modules/ai.nix
  ];

  home.username = "dididi";
  home.homeDirectory = "/home/dididi";
  home.stateVersion = "26.05";

  home.sessionVariables = {
    EDITOR = "hx";
  };

  programs.home-manager.enable = true;

  programs.git = {
    enable = true;
    ignores = globalGitIgnores;
    settings = {
      user = {
        name = "sg";
        email = "dfdgsdfg@gmail.com";
      };
      pager = {
        diff = "delta";
        log = "delta";
        reflog = "delta";
        show = "delta";
      };
      interactive.diffFilter = "delta --color-only --features=interactive";
      delta.features = "decorations";
      "delta \"interactive\"".keep-plus-minus-markers = false;
      "delta \"decorations\"" = {
        commit-decoration-style = "blue ol";
        commit-style = "raw";
        file-style = "omit";
        hunk-header-decoration-style = "blue box";
        hunk-header-file-style = "red";
        hunk-header-line-number-style = "#067a00";
        hunk-header-style = "file line-number syntax";
      };
      alias.root = "rev-parse --show-toplevel";
      fetch.pruneTags = true;
      pull.rebase = false;
      push.autoSetupRemote = true;
    };
  };

  programs.delta = {
    enable = true;
    enableGitIntegration = false;
  };

  home.file.".default-python-packages".text = ''
    pynvim
  '';

  home.file.".default-gems".text = ''
    bundler
    cocoapods
    fastlane
    neovim
  '';

  fonts.fontconfig.enable = true;
  nixpkgs.config = {
    allowUnfree = true;
    android_sdk.accept_license = true;
    permittedInsecurePackages = [
      "electron-39.8.10"
    ];
  };
}
