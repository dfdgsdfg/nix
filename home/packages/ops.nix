{ lib, pkgs, upstreamBinaries }:

(with pkgs; [
  kubernetes-helm
  kompose
  upstreamBinaries.terraform
])
++ lib.optionals pkgs.stdenv.hostPlatform.isDarwin (
  with pkgs;
  [
    colima
    lima
    mas
  ]
)
