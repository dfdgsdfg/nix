{ config, inputs, lib, pkgs, ... }:

let
  cloudflareSecrets = ../../../secrets/cloudflare.yaml;
in {
  imports = [
    ./hardware-configuration.nix
  ];

  boot.loader.systemd-boot = {
    enable = true;
    configurationLimit = 10;
  };
  boot.loader.efi.canTouchEfiVariables = true;
  networking.hostName = "sg-lenovo";
  networking.networkmanager.enable = true;
  nixpkgs.overlays = [ (import ../../../system/overlays/kime.nix) ];
  networking.firewall.allowedTCPPorts = [
    3389 # GNOME Remote Desktop (RDP)
    53317
  ];
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
  services.gnome.gnome-remote-desktop.enable = true;
  systemd.services.gnome-remote-desktop.wantedBy = [ "graphical.target" ];

  sops = {
    defaultSopsFile = cloudflareSecrets;
    age.keyFile = "/home/dididi/.config/sops/age/keys.txt";
    useSystemdActivation = true;
    secrets.cloudflare-tunnel-token = {
      mode = "0400";
      restartUnits = [ "cloudflared.service" ];
    };
  };

  systemd.services.cloudflared = {
    description = "Cloudflare Tunnel";
    wantedBy = [ "multi-user.target" ];
    wants = [ "network-online.target" ];
    requires = [ "sops-install-secrets.service" ];
    after = [ "network-online.target" "sops-install-secrets.service" ];
    serviceConfig = {
      DynamicUser = true;
      LoadCredential = "tunnel-token:${config.sops.secrets.cloudflare-tunnel-token.path}";
      ExecCondition = "${pkgs.gnugrep}/bin/grep --quiet ^eyJ %d/tunnel-token";
      ExecStart = "${pkgs.cloudflared}/bin/cloudflared tunnel --no-autoupdate run --token-file %d/tunnel-token";
      Restart = "on-failure";
      RestartSec = "5s";
    };
  };

  # Keep the laptop available as a server while connected to AC power.
  # The battery lid-close policy remains at its default (suspend).
  services.logind.settings.Login.HandleLidSwitchExternalPower = "ignore";

  services.openssh = {
    enable = true;
    openFirewall = true;
    settings = {
      AllowUsers = [ "dididi" ];
      AuthenticationMethods = "publickey";
      KbdInteractiveAuthentication = false;
      PasswordAuthentication = false;
      PermitRootLogin = "no";
    };
  };

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
        f11 = "brightnessdown";
        f12 = "brightnessup";
      };
      settings.shift = {
        leftshift = "capslock";
        rightshift = "capslock";
      };
    };
  };

  services.printing.enable = true;

  services.tailscale = {
    enable = true;
    openFirewall = true;
  };

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
    openssh.authorizedKeys.keys = [
      "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIH6ax5WnlNo8xT6qvvKQbCyHtC5cvTgwX2aPC48CxD5x dfdgsdfg@gmail.com"
    ];
  };

  nixpkgs.config.allowUnfree = true;
  nix.settings = {
    experimental-features = [ "nix-command" "flakes" ];
    auto-optimise-store = true;
  };
  nix.gc = {
    automatic = true;
    dates = "weekly";
    options = "";
  };
  systemd.services.nix-gc = {
    path = [ config.nix.package pkgs.coreutils pkgs.findutils ];
    preStart = ''
      ${pkgs.bash}/bin/bash ${../../../scripts/prune-nixos-generations.sh} \
        /nix/var/nix/profiles/system 5 30
    '';
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
