{ lib, ... }:

{
  modules.packages = {
    mobile.enable = lib.mkForce false;
  };
}
