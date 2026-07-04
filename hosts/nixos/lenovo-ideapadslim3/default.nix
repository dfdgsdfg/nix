{ config, inputs, lib, pkgs, ... }:

{
  imports = [
    ./hardware-configuration.nix
  ];

  boot.loader.systemd-boot = {
    enable = true;
    configurationLimit = 10;
  };
  boot.loader.efi.canTouchEfiVariables = true;
  boot.kernelPackages = pkgs.linuxPackages_7_0;

  networking.hostName = "lenovo-ideapadslim3";
  networking.networkmanager.enable = true;
  networking.firewall.allowedTCPPorts = [ 53317 ];
  networking.firewall.allowedUDPPorts = [ 53317 5353 ];

  time.timeZone = "Asia/Seoul";

  i18n = {
    defaultLocale = "ko_KR.UTF-8";
    inputMethod = {
      enable = true;
      type = "kime";
    };
    extraLocaleSettings = {
      LC_ADDRESS = "ko_KR.UTF-8";
      LC_IDENTIFICATION = "ko_KR.UTF-8";
      LC_MEASUREMENT = "ko_KR.UTF-8";
      LC_MONETARY = "ko_KR.UTF-8";
      LC_NAME = "ko_KR.UTF-8";
      LC_NUMERIC = "ko_KR.UTF-8";
      LC_PAPER = "ko_KR.UTF-8";
      LC_TELEPHONE = "ko_KR.UTF-8";
      LC_TIME = "ko_KR.UTF-8";
    };
  };

  services.xserver = {
    enable = true;
    xkb = {
      layout = "kr";
      variant = "";
    };
  };
  services.displayManager.gdm.enable = true;
  services.desktopManager.gnome.enable = true;

  services.keyd = {
    enable = true;
    keyboards.default = {
      ids = [
        "0001:0001:09b4e68d" # AT Translated Set 2 keyboard
        "0000:0006:bdb72f48" # Video Bus
      ];
      settings.main = {
        leftmeta = "layer(alt)";
        leftalt = "layer(meta)";
        rightalt = "layer(meta)";
        rightcontrol = "layer(alt)";
        capslock = "overloadt2(shift, hangeul, 200)";
      };
      settings.shift = {
        leftshift = "capslock";
        rightshift = "capslock";
      };
    };
  };

  services.printing.enable = true;

  services.pulseaudio.enable = false;
  security.rtkit.enable = true;
  services.pipewire = {
    enable = true;
    alsa.enable = true;
    alsa.support32Bit = true;
    pulse.enable = true;
  };
  services.illum.enable = false;

  users.users.dididi = {
    isNormalUser = true;
    description = "dididi";
    extraGroups = [ "networkmanager" "wheel" ];
    shell = pkgs.fish;
  };

  nixpkgs.config.allowUnfree = true;
  nix.settings = {
    experimental-features = [ "nix-command" "flakes" ];
    auto-optimise-store = true;
  };
  nix.gc = {
    automatic = true;
    dates = "weekly";
    options = "--delete-older-than 1w";
  };

  modules.systemPackages = {
    core.enable = true;
    workstation.enable = true;
    fish.enable = true;
    games.enable = true;
    nixLd.enable = true;
  };

  programs.nixvim = {
    enable = true;
    nixpkgs.source = inputs.nixpkgs;
    colorschemes.catppuccin.enable = true;
    plugins.lualine.enable = true;
    clipboard.providers.wl-copy.enable = true;
  };

  system.stateVersion = "26.05";
}
