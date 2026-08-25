{ ... }:

let
  sshSecrets = ../../secrets/ssh.yaml;
in
{
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
}
