{ ... }:

{
  imports = [
    ../../../packages
    ../../../profiles/personal.nix
    ../../../profiles/work-us.nix
  ];

  modules.packages = {
    core.enable = true;
    dev.enable = true;
    network.enable = true;
    ops.enable = true;
  };
}
