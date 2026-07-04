{ pkgs, ... }:

{
  home.packages = with pkgs; [
    bespokesynth
    supercollider
  ];
}
