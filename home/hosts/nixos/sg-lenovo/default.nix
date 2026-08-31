{ ... }:

{
  imports = [
    ../../../packages
    ../../../profiles/nixos/desktop.nix
    ./ssh.nix
  ];

  modules.packages = {
    core.enable = true;
    dev.enable = true;
    network.enable = true;
    ops.enable = true;
  };

  modules.omp.apiKeyCommand = "!secret-tool lookup service omniroute client sg-lenovo-omp";
}
