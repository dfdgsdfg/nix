{ lib, ... }:

{
  modules.packages = {
    gui.enable = lib.mkForce false;
    mobile.enable = lib.mkForce false;
  };
}
