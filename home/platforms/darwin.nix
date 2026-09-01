{ config, lib, pkgs, ... }:

let
  home = config.home.homeDirectory;
  pathOrder = import ../path-order.nix;
  brewPrefix =
    if pkgs.stdenv.hostPlatform.isAarch64 then
      "/opt/homebrew"
    else
      "/usr/local";
in
{
  # Darwin extends the common PATH with user tools, then Homebrew before the
  # inherited Nix profiles and OS fallback paths.
  home.sessionPath = lib.mkMerge [
    (lib.mkOrder pathOrder.userExtra [
      "${home}/.codeium/windsurf/bin"
    ])
    (lib.mkOrder pathOrder.homebrew [
      "${brewPrefix}/bin"
      "${brewPrefix}/sbin"
    ])
  ];

  home.sessionVariables = {
    HOMEBREW_PREFIX = brewPrefix;
    HOMEBREW_CELLAR = "${brewPrefix}/Cellar";
    HOMEBREW_REPOSITORY = brewPrefix;
    INFOPATH = "${brewPrefix}/share/info:";
  };

  home.file."Library/Application Support/jj/config.toml".text = ''
    [ui]
    default-command = "log"

    [user]
    name = "dididi"
    email = "dfdgsdfg@gmail.com"
  '';

  programs.fish.shellInit = lib.mkAfter ''
    fish_add_path --append --path /run/current-system/sw/bin
    test -r "$HOME/.orbstack/shell/init2.fish"; and source "$HOME/.orbstack/shell/init2.fish"
  '';

  programs.zsh.initContent = lib.mkAfter ''
    if [ -f "$HOME/.dart-cli-completion/zsh-config.zsh" ]; then
      . "$HOME/.dart-cli-completion/zsh-config.zsh"
    fi

    if [ -f "$HOME/.orbstack/shell/init.zsh" ]; then
      . "$HOME/.orbstack/shell/init.zsh"
    fi
  '';

  programs.ssh.settings."*" = {
    IgnoreUnknown = "UseKeychain";
    UseKeychain = true;
  };
}
