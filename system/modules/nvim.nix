{
  config,
  inputs,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.modules.nvim;
  nvim = import ../../modules/nvim/package.nix {
    inherit inputs pkgs;
    includeFlutter = false;
  };
in
{
  options.modules.nvim.enable = lib.mkEnableOption "Nix-wrapped LazyVim configuration";

  config = lib.mkIf cfg.enable {
    environment.systemPackages = nvim.runtimePackages ++ [ nvim.package ];
  };
}
