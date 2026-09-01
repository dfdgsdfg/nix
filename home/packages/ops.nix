{
  lib,
  pkgs,
  upstreamBinaries,
}:

lib.optionals (!pkgs.stdenv.hostPlatform.isDarwin) [
  upstreamBinaries.terraform
]
