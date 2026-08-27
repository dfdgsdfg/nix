{ inputs, pkgs, ... }:
{
  system.primaryUser = "dididi";

  nixpkgs = {
    hostPlatform = "aarch64-darwin";
    config.allowUnfreePredicate = _: true;
  };

  determinateNix = {
    enable = true;
    registry.unstable.flake = inputs.nixpkgs-unstable;
    customSettings.experimental-features = [
      "nix-command"
      "flakes"
    ];
  };

  users.users.dididi = {
    home = "/Users/dididi";
    shell = pkgs.zsh;
  };

  modules.systemPackages.core.enable = true;

  homebrew = {
    enable = true;
    onActivation = {
      autoUpdate = true;
      upgrade = true;
    };
    taps = [
      "homebrew/bundle"
    ];
    # Keep Homebrew for app delivery. Formulae stay here only when Nix is missing or broken.
    brews = [
      "mas"
      "mole"
      "pidof"
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
      "google-chrome"
      "handbrake"
      "hex-fiend"
      "imageoptim"
      "iina"
      "input-source-pro"
      "keyboard-cleaner"
      "knuff"
      "logseq"
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
      "Color Picker" = 1545870783;
      "Dark Reader for Safari" = 1438243180;
      DeArrow = 6451469297;
      Kaleidoscope = 1575557335;
      Keka = 470158793;
      "Microsoft Remote Desktop" = 1295203466;
      "PDF Expert" = 1055273043;
      "Remote Desktop" = 409907375;
      Slack = 803453959;
      SnippetsLab = 1006087419;
      SocialFocus = 1661093205;
      SponsorBlock = 1573461917;
      Speedtest = 1153157709;
      TestFlight = 899247664;
      Transporter = 1450874784;
      "Turn Off the Lights for Safari" = 1273998507;
      UnTrap = 1637438059;
      Unicorn = 1231935892;
      Userscripts = 1463298887;
    };
  };

  fonts.packages = [
    pkgs.nerd-fonts.meslo-lg
  ];

  programs.zsh.enable = true;

  system.stateVersion = 6;
}
