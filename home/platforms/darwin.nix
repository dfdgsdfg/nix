{ config, lib, pkgs, ... }:

let
  home = config.home.homeDirectory;
  brewPrefix =
    if pkgs.stdenv.hostPlatform.isAarch64 then
      "/opt/homebrew"
    else
      "/usr/local";
in
{
  home.sessionPath = lib.mkAfter [
    "${brewPrefix}/bin"
    "${brewPrefix}/sbin"
    "${home}/.codeium/windsurf/bin"
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
