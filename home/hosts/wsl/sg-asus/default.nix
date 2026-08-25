{ lib, ... }:

{
  imports = [ ./ssh.nix ];

  modules.packages = {
    mobile.enable = lib.mkForce false;
  };
}
