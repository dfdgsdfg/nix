{ lib, pkgs, ... }:

let
  upstreamBinaries = import ../packages/upstream-binaries.nix { inherit lib pkgs; };
in
{
  # Linux PATH policy: common mise paths -> inherited Nix profiles.
  home.packages = with pkgs; [
    aria2
    dnsutils
    ethtool
    iftop
    illum
    ipcalc
    iperf3
    iotop
    ldns
    libsecret
    lm_sensors
    lsof
    ltrace
    macchina
    mtr
    nmap
    upstreamBinaries.opencode
    p7zip
    pciutils
    socat
    strace
    sysstat
    usbutils
    xz
    zip
  ];

  # buildEnv merges application icons from many packages, but an individual
  # package's cache can win the icon-theme.cache collision. Rebuild the cache
  # after the complete Home Manager profile has been assembled.
  home.extraProfileCommands = ''
    iconThemeDir="$out/share/icons/hicolor"
    if [ -d "$iconThemeDir" ]; then
      rm -f "$iconThemeDir/icon-theme.cache"
      ${pkgs.gtk3}/bin/gtk-update-icon-cache --force "$iconThemeDir"
    fi
  '';

  modules.omp.apiKeyCommand = lib.mkDefault "!secret-tool lookup service omniroute client $HOSTNAME-omp";
}
