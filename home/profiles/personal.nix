{
  config,
  lib,
  pkgs,
  ...
}:

let
  homeSecrets = ../../secrets/home.yaml;
in
{
  imports = [ ./ssh.nix ];

  sops = {
    age.keyFile = lib.mkDefault "${config.home.homeDirectory}/.config/sops/age/keys.txt";
    secrets."git/config-user" = {
      format = "yaml";
      sopsFile = homeSecrets;
      key = "git/config_user";
      path = "${config.xdg.configHome}/git/config-user";
      mode = "0600";
    };
    secrets."git/config-user-work" = {
      format = "yaml";
      sopsFile = homeSecrets;
      key = "git/config_user_work";
      path = "${config.xdg.configHome}/git/config-user-work";
      mode = "0600";
    };
    secrets."git/config-user-work-us" = {
      format = "yaml";
      sopsFile = homeSecrets;
      key = "git/config_user_work_us";
      path = "${config.xdg.configHome}/git/config-user-work-us";
      mode = "0600";
    };
    secrets."fish/credential" = {
      format = "yaml";
      sopsFile = homeSecrets;
      key = "fish/credential";
      path = "${config.xdg.configHome}/fish/credential.fish";
      mode = "0600";
    };
  };

  modules.ssh = {
    settings = {
      "github.com" = {
        User = "git";
        HostName = "github.com";
        IdentityFile = "~/.ssh/id_ed25519";
        IdentitiesOnly = true;
        Compression = true;
      };
    };
  };

  programs.git.settings.include.path = "${config.xdg.configHome}/git/config-user";

  programs.fish.shellInit = lib.mkAfter ''
    if test -f "${config.xdg.configHome}/fish/credential.fish"
      source "${config.xdg.configHome}/fish/credential.fish"
    end
  '';

  home.sessionVariables.SOPS_AGE_KEY_FILE = "${config.home.homeDirectory}/.config/sops/age/keys.txt";

  sops.secrets."jj/config" = {
    format = "yaml";
    sopsFile = homeSecrets;
    key = "jj/config";
    path =
      if pkgs.stdenv.hostPlatform.isDarwin then
        "${config.home.homeDirectory}/Library/Application Support/jj/config.toml"
      else
        "${config.xdg.configHome}/jj/config.toml";
    mode = "0600";
  };
}
