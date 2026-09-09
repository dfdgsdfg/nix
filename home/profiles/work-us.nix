{ config, lib, ... }:

let
  sshSecrets = ../../secrets/work-us.yaml;
in
{
  imports = [ ../modules/ssh ];

  sops = {
    age.keyFile = lib.mkDefault "${config.home.homeDirectory}/.config/sops/age/keys.txt";
    secrets."ssh/us_sg_ed25519" = {
      format = "yaml";
      sopsFile = sshSecrets;
      key = "ssh/us_sg_ed25519";
    };
    secrets."ssh/us_sg_ed25519.pub" = {
      format = "yaml";
      sopsFile = sshSecrets;
      key = "ssh/us_sg_ed25519_pub";
    };
  };

  modules.ssh = {
    enable = true;
    identities.work-us = {
      secret = "ssh/us_sg_ed25519";
      target = ".ssh/us_sg_ed25519";
      publicKeySecret = "ssh/us_sg_ed25519.pub";
    };
  };
}
