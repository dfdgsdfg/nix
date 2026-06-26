{ config, lib, ... }:
let
  cfg = config.modules.ssh;

  targetPath = target:
    if lib.hasPrefix "/" target then
      target
    else
      "${config.home.homeDirectory}/${target}";

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

      publicKeySecret = lib.mkOption {
        type = lib.types.nullOr lib.types.str;
        default = null;
        description = "Optional SOPS secret that stores the public key to write alongside the private key.";
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

  secretFileSubmodule = lib.types.submodule ({ name, ... }: {
    options = {
      secret = lib.mkOption {
        type = lib.types.str;
        default = name;
        description = "Attribute path (slash-separated) pointing to the SOPS secret to expose.";
      };

      target = lib.mkOption {
        type = lib.types.str;
        default = ".ssh/${name}";
        description = "Relative or absolute target path for the decrypted secret.";
      };

      mode = lib.mkOption {
        type = lib.types.str;
        default = "0600";
        description = "File mode to apply to the decrypted secret.";
      };
    };
  });

  mkSecretAssignment = { secret, target, mode }: {
    ${secret} = {
      path = targetPath target;
      inherit mode;
    };
  };

  mkIdentitySecretAssignments = { name, value, ... }:
    let
      identity = value;
      pkTarget =
        if identity.publicKeyTarget != null then
          identity.publicKeyTarget
        else
          identity.target + ".pub";
    in
    [
      (mkSecretAssignment {
        secret = identity.secret;
        target = identity.target;
        mode = identity.mode;
      })
    ]
    ++ lib.optionals (identity.publicKeySecret != null) [
      (mkSecretAssignment {
        secret = identity.publicKeySecret;
        target = pkTarget;
        mode = identity.publicKeyMode;
      })
    ];

  mkIdentityPublicFiles = { value, ... }:
    let
      identity = value;
      pkTarget =
        if identity.publicKeyTarget != null then
          identity.publicKeyTarget
        else
          identity.target + ".pub";
    in
    lib.optionals (identity.publicKey != null) [
      {
        name = pkTarget;
        value = {
          text = identity.publicKey;
        };
      }
    ];

  mkSecretFileAssignment = { value, ... }:
    mkSecretAssignment {
      inherit (value) secret target mode;
    };
in
{
  options.modules.ssh = {
    enable = lib.mkEnableOption "Manage SSH configuration and keys via Home Manager";

    identities = lib.mkOption {
      type = lib.types.attrsOf identitySubmodule;
      default = { };
      description = "SSH identities whose private keys are sourced from SOPS secrets.";
    };

    secretFiles = lib.mkOption {
      type = lib.types.attrsOf secretFileSubmodule;
      default = { };
      description = "Additional SSH-related files sourced from SOPS secrets.";
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
      identityList =
        lib.mapAttrsToList
          (name: value: { inherit name value; })
          cfg.identities;

      secretFileList =
        lib.mapAttrsToList
          (name: value: { inherit name value; })
          cfg.secretFiles;

      sopsSecretAssignments =
        lib.concatLists [
          (lib.concatMap mkIdentitySecretAssignments identityList)
          (map mkSecretFileAssignment secretFileList)
        ];

      identityPublicFiles =
        lib.listToAttrs (
          lib.concatMap mkIdentityPublicFiles identityList
        );
    in
    {
      programs.ssh = {
        enable = true;
        matchBlocks = cfg.matchBlocks;
        extraConfig = lib.optionalString (cfg.extraConfig != "") cfg.extraConfig;
      };

      sops.secrets = lib.mkMerge sopsSecretAssignments;

      home.file = identityPublicFiles;
    }
  );
}
