{
  config,
  inputs,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.modules.nvim;
  nvim = import ./package.nix {
    inherit inputs pkgs;
    includeFlutter = true;
  };
in
{
  options.modules.nvim.enable = lib.mkEnableOption "Nix-wrapped LazyVim configuration";

  config = lib.mkIf cfg.enable {
    home.packages = nvim.runtimePackages ++ [ nvim.package ];
  };
}
