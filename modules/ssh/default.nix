{ config, lib, ... }:
let
  cfg = config.modules.ssh;

  identitySubmodule = lib.types.submodule ({ name, ... }: {
    options = {
      secret = lib.mkOption {
        type = lib.types.str;
        description = "Attribute path (slash-separated) pointing to the SOPS secret that stores the private key.";
        example = "ssh/github/id_ed25519";
      };

      target = lib.mkOption {
        type = lib.types.str;
        default = ".ssh/${name}";
        description = "Relative path (under the home directory) where the decrypted private key will be written.";
      };

      mode = lib.mkOption {
        type = lib.types.str;
        default = "0600";
        description = "File mode to apply to the private key.";
      };

      publicKey = lib.mkOption {
        type = lib.types.nullOr lib.types.str;
        default = null;
        description = "Optional public key text to write alongside the private key.";
      };

      publicKeyTarget = lib.mkOption {
        type = lib.types.nullOr lib.types.str;
        default = null;
        description = "Explicit path for the public key file. Defaults to <target>.pub when unset.";
      };

      publicKeyMode = lib.mkOption {
        type = lib.types.str;
        default = "0644";
        description = "File mode for the public key when it is provided.";
      };
    };
  });

  mkIdentityFiles = { name, value }:
    let
      identity = value;
      secretPath = lib.splitString "/" identity.secret;
      hasSecret = lib.hasAttrByPath secretPath config.sops.secrets;
      _ = lib.assertMsg hasSecret ''
        modules.ssh.identities."${name}".secret must reference an existing entry in config.sops.secrets (got "${identity.secret}")
      '';
      secret = lib.attrByPath secretPath config.sops.secrets;
      pkTarget =
        if identity.publicKeyTarget != null then
          identity.publicKeyTarget
        else
          identity.target + ".pub";
    in
    [
      {
        name = identity.target;
        value = {
          source = secret.path;
          mode = identity.mode;
        };
      }
    ]
    ++ lib.optionals (identity.publicKey != null) [
      {
        name = pkTarget;
        value = {
          text = identity.publicKey;
          mode = identity.publicKeyMode;
        };
      }
    ];
in
{
  options.modules.ssh = {
    enable = lib.mkEnableOption "Manage SSH configuration and keys via Home Manager";

    identities = lib.mkOption {
      type = lib.types.attrsOf identitySubmodule;
      default = { };
      description = "SSH identities whose private keys are sourced from SOPS secrets.";
    };

    matchBlocks = lib.mkOption {
      type = lib.types.attrsOf (lib.types.attrsOf lib.types.anything);
      default = { };
      example = {
        "github.com" = {
          user = "git";
          hostname = "github.com";
          identityFile = "~/.ssh/github_ed25519";
        };
      };
      description = "Match block configuration forwarded to programs.ssh.matchBlocks.";
    };

    extraConfig = lib.mkOption {
      type = lib.types.lines;
      default = "";
      description = "Additional SSH configuration appended verbatim to ~/.ssh/config.";
    };
  };

  config = lib.mkIf cfg.enable (
    let
      identityFiles =
        lib.listToAttrs (
          lib.concatMap
            mkIdentityFiles
            (lib.mapAttrsToList
              (name: value: { inherit name value; })
              cfg.identities
            )
        );
    in
    {
      programs.ssh = {
        enable = true;
        matchBlocks = cfg.matchBlocks;
        extraConfig = lib.optionalString (cfg.extraConfig != "") cfg.extraConfig;
      };

      home.file = lib.mkMerge [ identityFiles ];
    }
  );
}
