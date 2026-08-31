{ ... }:

{
  imports = [
    ../../../packages
    ./ssh.nix
  ];

  modules.packages = {
    core.enable = true;
    dev.enable = true;
    network.enable = true;
    ops.enable = true;
  };
}
