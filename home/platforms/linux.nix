{ lib, pkgs, ... }:

{
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
    opencode
    p7zip
    pciutils
    socat
    strace
    sysstat
    usbutils
    xz
    zip
  ];

  modules.omp.apiKeyCommand = lib.mkDefault "!secret-tool lookup service omniroute client $HOSTNAME-omp";
}
