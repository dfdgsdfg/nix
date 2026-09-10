{
  config,
  lib,
  pkgs,
  ...
}:

let
  homeSecrets = ../../secrets/home.yaml;
  personalAgentsSecrets = ../../secrets/personal-agents.yaml;
  platform = if pkgs.stdenv.hostPlatform.isDarwin then "darwin" else "linux";
  keychainAuth = pkgs.writeShellScriptBin "omniroute-personal-auth" ''
    exec ${pkgs.python3}/bin/python ${../modules/omniroute-personal/keychain-auth.py} "$@"
  '';
  mkKeychainCommand =
    {
      keyPath,
      service,
      client,
      label,
    }:
    let
      keychainArgs =
        [
          "--platform"
          platform
          "--account"
          config.home.username
          "--sops-file"
          keyPath
          "--service"
          service
          "--client"
          client
          "--label"
          label
        ]
        ++ lib.optionals pkgs.stdenv.hostPlatform.isDarwin [
          "--security"
          "/usr/bin/security"
        ]
        ++ lib.optionals pkgs.stdenv.hostPlatform.isLinux [
          "--secret-tool"
          "${pkgs.libsecret}/bin/secret-tool"
        ];
    in
    "!${keychainAuth}/bin/omniroute-personal-auth ${lib.concatStringsSep " " (map lib.escapeShellArg keychainArgs)}";
in
{
  imports = [ ./ssh.nix ];

  sops = {
    age.keyFile = lib.mkDefault "${config.home.homeDirectory}/.config/sops/age/keys.txt";
    secrets."personal-pi" = {
      format = "yaml";
      sopsFile = personalAgentsSecrets;
      key = "personal-pi";
      path = "${config.xdg.configHome}/omniroute/personal-pi.key";
      mode = "0400";
    };
    secrets."personal-omp" = {
      format = "yaml";
      sopsFile = personalAgentsSecrets;
      key = "personal-omp";
      path = "${config.xdg.configHome}/omniroute/personal-omp.key";
      mode = "0400";
    };
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

  modules.pi.apiKeyCommand = mkKeychainCommand {
    keyPath = config.sops.secrets."personal-pi".path;
    service = "omniroute-personal-pi";
    client = "personal-pi";
    label = "OmniRoute personal Pi";
  };
  modules.omp.apiKeyCommand = mkKeychainCommand {
    keyPath = config.sops.secrets."personal-omp".path;
    service = "omniroute-personal-omp";
    client = "personal-omp";
    label = "OmniRoute personal OMP";
  };

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
