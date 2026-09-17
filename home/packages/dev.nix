{ lib, pkgs }:

(with pkgs; [
  b3sum
  ccache
  cmake
  chezmoi
  grex
  lefthook
])
++ [ (import ./d2.nix { inherit lib pkgs; }) ]
++ lib.optionals (!pkgs.stdenv.hostPlatform.isDarwin) (
  with pkgs;
  [
    bfg-repo-cleaner
    google-cloud-sdk
    imagemagick
  ]
)
