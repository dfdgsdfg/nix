{
  lib,
  pkgs,
  stablePkgs,
  unstablePkgs,
  upstreamBinaries,
}:

(with pkgs; [
  age
  atuin
  bat
  bottom
  broot
  curl
  delta
  duf
  dust
  fd
  fx
  fzf
  gawk
  grc
  gh
  git
  git-lfs
  gitui
  glow
  gnupg
  jq
  lazygit
  lsd
  minisign
  # Unstable mosh cannot compile against its new protobuf/Abseil dependencies.
  (if stdenv.hostPlatform.isLinux then stablePkgs.mosh else mosh)
  navi
  nushell
  pipx
  pinentry-curses
  procs
  ripgrep
  sd
  skim
  sqlite
  sops
  tmux
  tree-sitter
  unzip
  wget
  xh
  yq-go
  yazi
  zellij
  zoxide
])
++ lib.optionals (!pkgs.stdenv.hostPlatform.isDarwin) (
  with pkgs;
  [
    fnox
    upstreamBinaries.herdr
    mole
    trash-cli
  ]
)
++ (with unstablePkgs; [
  fastfetch
])
