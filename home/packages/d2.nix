{ lib, pkgs }:
let
  driver = pkgs.playwright-driver;
  # The bundled WebKit links libmanette, missing from its nixpkgs buildInputs.
  components = driver.components // {
    webkit = driver.components.webkit.overrideAttrs (old: {
      buildInputs = (old.buildInputs or [ ]) ++ [ pkgs.libmanette ];
    });
  };
  browsers = pkgs.linkFarm "playwright-browsers" (lib.mapAttrs' (name: package:
    lib.nameValuePair
      "${lib.replaceStrings [ "-" ] [ "_" ] name}-${driver.browsersJSON.${name}.revision}"
      package
  ) components);
in
if pkgs.stdenv.hostPlatform.isLinux then
  pkgs.d2.override {
    playwright-driver = driver // { inherit browsers; };
  }
else
  pkgs.d2
