{ config, lib, pkgs, inputs, pkgsUnstable ? null, ... }:
let
  cfg = config.modules.packages;
  system = pkgs.stdenv.hostPlatform.system;
  unstablePkgs = pkgsUnstable or import inputs.nixpkgs-unstable {
    inherit system;
    config.allowUnfree = true;
  };

  corePkgs =
    (with pkgs; [
      age
      atuin
      bat
      bottom
      delta
      dust
      fd
      fzf
      gh
      git
      git-lfs
      gitui
      glow
      gnupg
      jq
      lazygit
      lsd
      mise
      mosh
      navi
      nushell
      pipx
      pinentry
      procs
      ripgrep
      sd
      skim
      sqlite
      sops
      tmux
      tree-sitter
      tree-sitter-cli
      trash-cli
      unzip
      wget
      yq
      zellij
      zoxide
    ])
    ++ (with unstablePkgs; [
      fastfetch
    ]);

  devPkgs = with pkgs; [
    b3sum
    bfg-repo-cleaner
    bitwarden-cli
    cmake
    chezmoi
    d2
    google-cloud-sdk
    gradle
    grex
    helix
    imagemagick
    lefthook
    nodejs_20
  ];

  networkPkgs = with pkgs; [
    bandwhich
    cloudflared
    mitmproxy
    whalebrew
  ];

  opsPkgs =
    (with pkgs; [
      kubernetes-helm
      kompose
      terraform
    ])
    ++ lib.optionals pkgs.stdenv.isDarwin (with pkgs; [
      colima
      lima
      mas
    ]);

  mobilePkgs =
    lib.optionals pkgs.stdenv.isDarwin (
      with pkgs; [
        ideviceinstaller
        libimobiledevice
        libimobiledevice-glue
        libplist
        libusbmuxd
      ]
    );

  guiPkgs = import ./apps.nix {
    inherit pkgs unstablePkgs;
  };
in
{
  options.modules.packages = {
    core.enable = lib.mkEnableOption "core CLI tooling";
    dev.enable = lib.mkEnableOption "developer productivity tools";
    network.enable = lib.mkEnableOption "networking and debugging utilities";
    ops.enable = lib.mkEnableOption "DevOps and infrastructure tooling";
    mobile.enable = lib.mkEnableOption "mobile and device tooling";
    gui.enable = lib.mkEnableOption "graphical applications";
  };

  config.home.packages = lib.unique (
    lib.concatLists [
      lib.optionals cfg.core.enable corePkgs
      lib.optionals cfg.dev.enable devPkgs
      lib.optionals cfg.network.enable networkPkgs
      lib.optionals cfg.ops.enable opsPkgs
      lib.optionals cfg.mobile.enable mobilePkgs
      lib.optionals cfg.gui.enable guiPkgs
    ]
  );
}
