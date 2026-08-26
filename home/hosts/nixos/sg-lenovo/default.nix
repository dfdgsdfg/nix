{ lib, ... }:

{
  imports = [
    ../../../profiles/nixos/desktop.nix
    ./ssh.nix
  ];
  modules.nvim.enable = lib.mkForce false;
  modules.omp.apiKeyCommand = "!secret-tool lookup service omniroute client sg-lenovo-omp";
}
