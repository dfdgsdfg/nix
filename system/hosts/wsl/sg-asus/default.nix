{ pkgsUnstable, ... }:
{
  imports = [ ../../../profiles/nixos/wsl.nix ];

  networking.hostName = "sg-asus";
  environment.systemPackages = with pkgsUnstable; [
    yazi
  ];
}
