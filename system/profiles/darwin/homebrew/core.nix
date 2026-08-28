{
  # Keep Homebrew for app delivery. Formulae stay here only when Nix is missing or broken.
  homebrew = {
    enable = true;
    onActivation = {
      autoUpdate = true;
      upgrade = true;
    };
    brews = [
      "mas"
      "mole"
      "pidof"
    ];
  };
}
