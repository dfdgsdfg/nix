{ ... }:

{
  imports = [
    ../../../profiles/darwin/base.nix
    ./ssh.nix
  ];
  networking.hostName = "us-mbpro2311-sg";
}
