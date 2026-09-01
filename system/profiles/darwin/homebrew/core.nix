{
  # Keep Homebrew for app delivery. Formulae stay here only when Nix is missing or broken.
  homebrew = {
    enable = true;
    onActivation = {
      autoUpdate = false;
      upgrade = false;
    };
    brews = [
      "mas"
      "mole"
      "pidof"
    ];
  };
}
