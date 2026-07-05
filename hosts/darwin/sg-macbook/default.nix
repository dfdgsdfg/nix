{ lib, ... }:

{
  imports = [
    ../macbook
  ];

  networking.hostName = lib.mkForce "sg-macbook";
}
