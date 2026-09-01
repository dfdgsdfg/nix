{
  # Keep Homebrew for app delivery and intentionally mutable command-line tools.
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
