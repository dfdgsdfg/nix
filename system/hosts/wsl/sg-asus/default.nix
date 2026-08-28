{ ... }:
{
  imports = [
    ../../../profiles/nixos/wsl.nix
    ./ssh.nix
  ];

  networking.hostName = "sg-asus";
}
