{ inputs, pkgs, pkgsUnstable, ... }:
{
  networking.hostName = "macbook";
  nixpkgs = {
    hostPlatform = "aarch64-darwin";
    config.allowUnfreePredicate = _: true;
  };

  nix.settings.experimental-features = [ "nix-command" "flakes" ];
  nix.registry.unstable.flake = inputs.nixpkgs-unstable;
  services.nix-daemon.enable = true;

  users.users.dididi = {
    home = "/Users/dididi";
    shell = pkgs.zsh;
  };

  modules.systemPackages = {
    core.enable = true;
    darwinApps.enable = false;
  };

  homebrew = {
    enable = true;
    onActivation = {
      autoUpdate = true;
      upgrade = true;
      cleanup = "none";
    };
    taps = [
      "cjbassi/ytop"
      "homebrew/bundle"
      "neovim/neovim"
    ];
    brews = [
      "age"
      "atuin"
      "bandwhich"
      "bat"
      "bottom"
      "bfg"
      "bitwarden-cli"
      "chezmoi"
      "cloudflared"
      "colima"
      "dust"
      "fd"
      "fish"
      "fx"
      "fzf"
      "gawk"
      "gh"
      "git"
      "git-delta"
      "git-lfs"
      "gitui"
      "gnupg"
      "grex"
      "helix"
      "helm"
      "ideviceinstaller"
      "jq"
      "lefthook"
      "lsd"
      "mas"
      "minisign"
      "mise"
      "mole"
      "mosh"
      "navi"
      "neovim"
      "nushell"
      "pidof"
      "pipx"
      "procs"
      "ripgrep"
      "sd"
      "sk"
      "sops"
      "starship"
      "trash"
      "tree-sitter"
      "tree-sitter-cli"
      "wget"
      "whalebrew"
      "xh"
      "yq"
      "zellij"
      "zoxide"
    ];
    casks = [
      "android-studio"
      "bespoke"
      "bit-slicer"
      "chatgpt"
      "claude"
      "cloudflare-warp"
      "cursor"
      "discord"
      "figma"
      "font-meslo-lg-nerd-font"
      "ghostty"
      "gitup"
      "google-cloud-sdk"
      "google-chrome"
      "handbrake"
      "hex-fiend"
      "imageoptim"
      "iina"
      "input-source-pro"
      "keyboard-cleaner"
      "knuff"
      "logseq"
      "mitmproxy"
      "notion"
      "orbstack"
      "plugdata"
      "pusher"
      "rustdesk"
      "sigmaos"
      "smcfancontrol"
      "vcv-rack"
      "visual-studio-code"
      "vlc"
      "vysor"
      "warp"
      "wireshark"
      "zed"
      "zoom"
      "zotero"
    ];
    masApps = {
      Amphetamine = 937984704;
      Bitwarden = 1352778147;
      Boop = 1518425043;
      "Color Picker" = 1545870783;
      CrystalFetch = 6454431289;
      "Dark Reader for Safari" = 1438243180;
      DeArrow = 6451469297;
      exifpurge = 784466108;
      JPEGmini = 498944723;
      "JPG to PDF" = 498829562;
      Kaleidoscope = 1575557335;
      Keka = 470158793;
      "Microsoft Remote Desktop" = 1295203466;
      "Okta Verify" = 490179405;
      "PDF Expert" = 1055273043;
      "PDF Squeezer 3" = 504700302;
      "Remote Desktop" = 409907375;
      Slack = 803453959;
      SnippetsLab = 1006087419;
      SocialFocus = 1661093205;
      SponsorBlock = 1573461917;
      Speedtest = 1153157709;
      TestFlight = 899247664;
      Transporter = 1450874784;
      "Turn Off the Lights for Safari" = 1273998507;
      UTM = 1538878817;
      UnTrap = 1637438059;
      Unicorn = 1231935892;
      Userscripts = 1463298887;
      WireGuard = 1451685025;
    };
  };

  fonts.fonts = [
    (pkgs.nerdfonts.override { fonts = [ "Meslo" ]; })
  ];

  programs.zsh.enable = true;

  system.stateVersion = 6;
}
