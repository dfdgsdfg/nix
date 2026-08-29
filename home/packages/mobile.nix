{ lib, pkgs }:

lib.optionals pkgs.stdenv.hostPlatform.isDarwin (
  with pkgs;
  [
    ideviceinstaller
    libimobiledevice
    libimobiledevice-glue
    libplist
    libusbmuxd
  ]
)
