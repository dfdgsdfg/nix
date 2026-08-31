{ ... }:

{
  imports = [
    ../../../profiles/darwin/base.nix
    ../../../profiles/darwin/homebrew
    ./ssh.nix
  ];
  networking.hostName = "sg-macbook";
}
