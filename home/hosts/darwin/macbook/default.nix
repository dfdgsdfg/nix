{ config, lib, ... }:
let
  home = config.home.homeDirectory;
  sshSecrets = ../../../../secrets/ssh.yaml;
in
{
  modules.packages.gui.enable = lib.mkForce false;

  sops.secrets = {
    "ssh/id_ed25519" = {
      format = "yaml";
      sopsFile = sshSecrets;
      key = "ssh/id_ed25519";
    };
    "ssh/id_ed25519.pub" = {
      format = "yaml";
      sopsFile = sshSecrets;
      key = "ssh/id_ed25519_pub";
    };
    "ssh/id_rsa" = {
      format = "yaml";
      sopsFile = sshSecrets;
      key = "ssh/readonly_id_rsa";
    };
    "ssh/id_rsa.pub" = {
      format = "yaml";
      sopsFile = sshSecrets;
      key = "ssh/readonly_id_rsa_pub";
    };
    "ssh/id_rsa.pub.pem" = {
      format = "yaml";
      sopsFile = sshSecrets;
      key = "ssh/readonly_id_rsa_pub_pem";
    };
    "ssh/authorized_keys" = {
      format = "yaml";
      sopsFile = sshSecrets;
      key = "ssh/authorized_keys";
    };
    "ssh/config.d/hosts.conf" = {
      format = "yaml";
      sopsFile = sshSecrets;
      key = "ssh/config_d_hosts_conf";
    };
  };

  modules.ssh = {
    identities.default = {
      secret = "ssh/id_ed25519";
      target = ".ssh/id_ed25519";
      publicKeySecret = "ssh/id_ed25519.pub";
    };
    identities.rsa = {
      secret = "ssh/id_rsa";
      target = ".ssh/id_rsa";
      publicKeySecret = "ssh/id_rsa.pub";
    };
    secretFiles = {
      authorizedKeys = {
        secret = "ssh/authorized_keys";
        target = ".ssh/authorized_keys";
      };
      rsaPublicPem = {
        secret = "ssh/id_rsa.pub.pem";
        target = ".ssh/id_rsa.pub.pem";
        mode = "0644";
      };
      hostsConfig = {
        secret = "ssh/config.d/hosts.conf";
        target = ".ssh/config.d/hosts.conf";
      };
    };
    includes = [ "config.d/*" ];
    settings."*".IdentityFile = [
      "~/.ssh/id_ed25519"
      "~/.ssh/id_rsa"
    ];
  };

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
