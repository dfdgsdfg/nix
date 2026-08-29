{ lib, pkgs }:

(with pkgs; [
  kubernetes-helm
  kompose
  terraform
])
++ lib.optionals pkgs.stdenv.hostPlatform.isDarwin (
  with pkgs;
  [
    colima
    lima
    mas
  ]
)
