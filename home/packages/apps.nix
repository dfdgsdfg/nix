{ pkgs, unstablePkgs }:
let
  inherit (pkgs) stdenv;

  stableApps = with pkgs; [
    androidStudioPackages.stable
    dosbox-x
    handbrake
    logseq
    rustdesk
    sqlitebrowser
    vlc
    wireshark
  ];

  unstableApps = with unstablePkgs; [
    ghostty
    zed-editor
  ];
in
if stdenv.isDarwin then
  stableApps ++ unstableApps
else
  [ ]
