{ ... }:

{
  services.openssh = {
    enable = true;
    openFirewall = true;
    settings = {
      AllowUsers = [ "dididi" ];
      AuthenticationMethods = "publickey";
      KbdInteractiveAuthentication = false;
      PasswordAuthentication = false;
      PermitRootLogin = "no";
    };
  };

  users.users.dididi.openssh.authorizedKeys.keys = [
    "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIH6ax5WnlNo8xT6qvvKQbCyHtC5cvTgwX2aPC48CxD5x dfdgsdfg@gmail.com"
  ];
}
