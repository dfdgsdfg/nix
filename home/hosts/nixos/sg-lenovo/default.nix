{ ... }:

{
  imports = [
    ../../../profiles/nixos/desktop.nix
    ./ssh.nix
  ];
  modules.omp.apiKeyCommand = "!secret-tool lookup service omniroute client sg-lenovo-omp";
}
