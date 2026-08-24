{ pkgsUnstable, ... }:
{
  imports = [ ../../../system/profiles/nixos/wsl.nix ];

  networking.hostName = "sg-asus";
  environment.systemPackages = with pkgsUnstable; [
    yazi
  ];
}
