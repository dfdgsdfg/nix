{ pkgs }:

# Use XWayland so Electron can receive Korean input through kime-xim.
pkgs.discord-ptb.override {
  commandLineArgs = "--ozone-platform=x11";
}
