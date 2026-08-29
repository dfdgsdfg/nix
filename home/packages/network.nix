{ lib, pkgs }:

(with pkgs; [
  bandwhich
  cloudflared
  mitmproxy
])
++ lib.optional (pkgs.stdenv.hostPlatform.isDarwin && lib.hasAttr "whalebrew" pkgs) pkgs.whalebrew
