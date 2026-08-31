{ lib, pkgs }:

(with pkgs; [
  b3sum
  ccache
  cmake
  chezmoi
  d2
  grex
  lefthook
])
++ lib.optionals (!pkgs.stdenv.hostPlatform.isDarwin) (
  with pkgs;
  [
    bfg-repo-cleaner
    google-cloud-sdk
    imagemagick
  ]
)
