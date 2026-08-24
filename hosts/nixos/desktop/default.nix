{ lib, ... }:
{
  imports = [ ../../../system/profiles/nixos/desktop.nix ];
  networking.hostName = "desktop";
  time.timeZone = "UTC";

  boot.loader.systemd-boot.enable = lib.mkDefault true;
  boot.loader.efi.canTouchEfiVariables = lib.mkDefault true;
}
