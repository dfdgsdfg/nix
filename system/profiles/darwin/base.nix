{ config, inputs, pkgs, ... }:
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
    shell = pkgs.fish;
  };

  fonts.packages = [
    pkgs.nerd-fonts.meslo-lg
  ];

  environment.shells = [ pkgs.fish ];

  programs.fish.enable = true;
  programs.zsh.enable = true;

  system.activationScripts.postActivation.text = ''
    primaryUser=${config.system.primaryUser}
    desiredShell=/run/current-system/sw/bin/fish
    currentShell="$(/usr/bin/dscl . -read "/Users/$primaryUser" UserShell 2> /dev/null || true)"
    currentShell="''${currentShell#UserShell: }"

    if [ "$currentShell" != "$desiredShell" ]; then
      echo "setting $primaryUser login shell to $desiredShell..." >&2
      /usr/bin/chsh -s "$desiredShell" "$primaryUser"
    fi
  '';

  system.stateVersion = 6;
}
