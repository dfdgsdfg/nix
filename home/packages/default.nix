{
  config,
  lib,
  pkgs,
  inputs,
  pkgsUnstable ? null,
  ...
}:
let
  cfg = config.modules.packages;
  system = pkgs.stdenv.hostPlatform.system;
  unstablePkgs =
    if pkgsUnstable != null then
      pkgsUnstable
    else
      import inputs.nixpkgs-unstable {
        inherit system;
        config.allowUnfree = true;
      };

  packageGroups = {
    core = import ./core.nix {
      inherit inputs lib pkgs system unstablePkgs;
    };
    dev = import ./dev.nix { inherit pkgs; };
    network = import ./network.nix { inherit lib pkgs; };
    ops = import ./ops.nix { inherit lib pkgs; };
    mobile = import ./mobile.nix { inherit lib pkgs; };
  };
in
{
  options.modules.packages = {
    core.enable = lib.mkEnableOption "core CLI tooling";
    dev.enable = lib.mkEnableOption "developer productivity tools";
    network.enable = lib.mkEnableOption "networking and debugging utilities";
    ops.enable = lib.mkEnableOption "DevOps and infrastructure tooling";
    mobile.enable = lib.mkEnableOption "mobile and device tooling";
  };

  config.home.packages = lib.unique (
    lib.concatLists [
      (lib.optionals cfg.core.enable packageGroups.core)
      (lib.optionals cfg.dev.enable packageGroups.dev)
      (lib.optionals cfg.network.enable packageGroups.network)
      (lib.optionals cfg.ops.enable packageGroups.ops)
      (lib.optionals cfg.mobile.enable packageGroups.mobile)
    ]
  );
}
