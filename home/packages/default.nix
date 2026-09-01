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
  upstreamBinaries = import ./upstream-binaries.nix { inherit lib pkgs; };

  packageGroups = {
    core = import ./core.nix {
      inherit lib pkgs unstablePkgs upstreamBinaries;
    };
    dev = import ./dev.nix { inherit lib pkgs; };
    network = import ./network.nix { inherit pkgs; };
    ops = import ./ops.nix { inherit lib pkgs upstreamBinaries; };
  };
in
{
  options.modules.packages = {
    core.enable = lib.mkEnableOption "core CLI tooling";
    dev.enable = lib.mkEnableOption "developer productivity tools";
    network.enable = lib.mkEnableOption "networking and debugging utilities";
    ops.enable = lib.mkEnableOption "DevOps and infrastructure tooling";
  };

  config.home.packages = lib.unique (
    lib.concatLists [
      (lib.optionals cfg.core.enable packageGroups.core)
      (lib.optionals cfg.dev.enable packageGroups.dev)
      (lib.optionals cfg.network.enable packageGroups.network)
      (lib.optionals cfg.ops.enable packageGroups.ops)
    ]
  );
}
