# nixpkgs-unstable's ccache lists Linux-only elfutils as a check input, which
# fails Darwin evaluation. Take ccache from stable nixpkgs on Darwin until
# upstream guards it.
{ pkgs, inputs }:
if pkgs.stdenv.hostPlatform.isDarwin then
  (import inputs.nixpkgs { inherit (pkgs.stdenv.hostPlatform) system; }).ccache
else
  pkgs.ccache
