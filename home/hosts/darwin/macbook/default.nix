{ config, lib, ... }:
let
  home = config.home.homeDirectory;
in
{
  modules.packages.gui.enable = lib.mkForce false;

  home.sessionPath = lib.mkAfter [
    "${home}/.codeium/windsurf/bin"
  ];

  home.file."Library/Application Support/jj/config.toml".text = ''
    [ui]
    default-command = "log"

    [user]
    name = "dididi"
    email = "dfdgsdfg@gmail.com"
  '';

  programs.fish.shellInit = lib.mkAfter ''
    if test -x /opt/homebrew/bin/brew
      /opt/homebrew/bin/brew shellenv | source
    else if test -x /usr/local/bin/brew
      /usr/local/bin/brew shellenv | source
    end

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
