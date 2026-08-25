{ ... }:

{
  imports = [
    ../../../profiles/darwin/base.nix
    ./ssh.nix
  ];
  networking.hostName = "sg-macbook";
}
