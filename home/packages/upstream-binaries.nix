{ lib, pkgs }:

let
  system = pkgs.stdenv.hostPlatform.system;

  selectRelease = name: releases:
    releases.${system} or (throw "${name} does not provide an upstream binary for ${system}");

  mkRawBinary =
    {
      pname,
      version,
      releases,
      description,
      homepage,
      license,
    }:
    let
      release = selectRelease pname releases;
    in
    pkgs.stdenvNoCC.mkDerivation {
      inherit pname version;

      src = pkgs.fetchurl {
        inherit (release) url hash;
      };

      dontUnpack = true;

      installPhase = ''
        runHook preInstall
        install -Dm755 "$src" "$out/bin/${pname}"
        runHook postInstall
      '';

      meta = {
        inherit description homepage license;
        mainProgram = pname;
        platforms = builtins.attrNames releases;
        sourceProvenance = with lib.sourceTypes; [ binaryNativeCode ];
      };
    };

  herdr = mkRawBinary rec {
    pname = "herdr";
    version = "0.9.3";
    releases = {
      x86_64-linux = {
        url = "https://github.com/herdrdev/herdr/releases/download/v${version}/herdr-linux-x86_64";
        hash = "sha256-GKjcZfHC+khYhDRDVt6hz9kRxvBs9G+njhk/QIf026c=";
      };
      aarch64-darwin = {
        url = "https://github.com/herdrdev/herdr/releases/download/v${version}/herdr-macos-aarch64";
        hash = "sha256-UXOj4K5C1dGrfr+l1eYyn3w9I/jho2d8fOMjHaKIQVc=";
      };
    };
    description = "Terminal UI for managing coding agents";
    homepage = "https://github.com/herdrdev/herdr";
    license = lib.licenses.mit;
  };

  terraformRelease = selectRelease "terraform" {
    x86_64-linux = {
      asset = "linux_amd64";
      hash = "sha256-3JSvDu8RR3GK18ja6nku0Znj4Eku7BgNCtr6KmWoed8=";
    };
    aarch64-darwin = {
      asset = "darwin_arm64";
      hash = "sha256-Qs/fl61yL3kIX+InmwbUuGgBct41NLIu7d2aD7vnuPE=";
    };
  };
  terraform = pkgs.stdenvNoCC.mkDerivation rec {
    pname = "terraform";
    version = "1.16.4";

    src = pkgs.fetchurl {
      url = "https://releases.hashicorp.com/terraform/${version}/terraform_${version}_${terraformRelease.asset}.zip";
      inherit (terraformRelease) hash;
    };

    nativeBuildInputs = [ pkgs.unzip ];
    dontUnpack = true;

    installPhase = ''
      runHook preInstall
      unzip -q "$src"
      install -Dm755 terraform "$out/bin/terraform"
      install -Dm444 LICENSE.txt "$out/share/licenses/terraform/LICENSE.txt"
      runHook postInstall
    '';

    meta = {
      description = "Tool for building, changing, and versioning infrastructure";
      homepage = "https://www.terraform.io/";
      license = lib.licenses.bsl11;
      mainProgram = "terraform";
      platforms = [ "x86_64-linux" "aarch64-darwin" ];
      sourceProvenance = with lib.sourceTypes; [ binaryNativeCode ];
    };
  };

  codexRelease = selectRelease "codex" {
    x86_64-linux = {
      target = "x86_64-unknown-linux-musl";
      hash = "sha256-OTDzGsX8qGHqPkROJoPyYRkNlrY/uljgpAqHkXQ2nN8=";
    };
    aarch64-darwin = {
      target = "aarch64-apple-darwin";
      hash = "sha256-+tV6VoHKvO8h0yKvWuyTiXXPtxG18l1M5JB+ZWFhbQc=";
    };
  };
  codex = pkgs.stdenvNoCC.mkDerivation rec {
    pname = "codex";
    version = "0.159.3";

    src = pkgs.fetchurl {
      url = "https://github.com/openai/codex/releases/download/rust-v${version}/codex-package-${codexRelease.target}.tar.gz";
      inherit (codexRelease) hash;
    };

    dontUnpack = true;

    installPhase = ''
      runHook preInstall
      tar -xzf "$src"
      mkdir -p "$out"
      cp -R bin codex-package.json codex-path codex-resources "$out/"
      runHook postInstall
    '';

    meta = {
      description = "Lightweight coding agent that runs in your terminal";
      homepage = "https://github.com/openai/codex";
      license = lib.licenses.asl20;
      mainProgram = "codex";
      platforms = [ "x86_64-linux" "aarch64-darwin" ];
      sourceProvenance = with lib.sourceTypes; [ binaryNativeCode ];
    };
  };

  buzz =
    let
      pname = "buzz";
      version = "0.5.26";
      src = pkgs.fetchurl {
        url = "https://github.com/block/buzz/releases/download/desktop-v${version}/Buzz_${version}_amd64.AppImage";
        hash = "sha256-67HFouhjceRMawqqdO9X6AwphliNnxftpSTcQ4iTz0M=";
      };
      appimageContents = pkgs.appimageTools.extract {
        inherit pname version src;
      };
    in
    pkgs.appimageTools.wrapType2 {
      inherit pname version src;
      extraPkgs = pkgs: [ pkgs.elfutils pkgs.zstd ];

      extraInstallCommands = ''
        install -Dm444 ${appimageContents}/Buzz.desktop \
          $out/share/applications/Buzz.desktop
        substituteInPlace $out/share/applications/Buzz.desktop \
          --replace-fail 'Exec=buzz-desktop' "Exec=$out/bin/buzz %U" \
          --replace-fail 'Categories=' 'Categories=Network;Chat;'
        cp -R ${appimageContents}/usr/share/icons $out/share/
      '';

      meta = {
        description = "Community chat for people and AI agents";
        homepage = "https://buzz.xyz/";
        license = lib.licenses.asl20;
        mainProgram = "buzz";
        platforms = [ "x86_64-linux" ];
        sourceProvenance = with lib.sourceTypes; [ binaryNativeCode ];
      };
    };

  localsend =
    let
      pname = "localsend";
      version = "1.18.2";
      src = pkgs.fetchurl {
        url = "https://github.com/localsend/localsend/releases/download/v${version}/LocalSend-${version}-linux-x86-64.AppImage";
        hash = "sha256-GfIWE9GDT2yqaVFxE2cEYaPxC4CioxX4ZUjAZj2cCq8=";
      };
      appimageContents = pkgs.appimageTools.extract {
        inherit pname version src;
      };
    in
    pkgs.appimageTools.wrapType2 {
      inherit pname version src;

      extraInstallCommands = ''
        install -Dm444 ${appimageContents}/org.localsend.localsend_app.desktop \
          $out/share/applications/org.localsend.localsend_app.desktop
        substituteInPlace $out/share/applications/org.localsend.localsend_app.desktop \
          --replace-fail 'Exec=localsend_app' "Exec=$out/bin/localsend"
        cp -R ${appimageContents}/usr/share/icons $out/share/
        chmod u+w $out/share/icons/hicolor
        rm -f $out/share/icons/hicolor/icon-theme.cache
      '';

      meta = {
        description = "Open source cross-platform alternative to AirDrop";
        homepage = "https://localsend.org/";
        license = lib.licenses.asl20;
        mainProgram = "localsend";
        platforms = [ "x86_64-linux" ];
        sourceProvenance = with lib.sourceTypes; [ binaryNativeCode ];
      };
    };

  tether =
    let
      pname = "tether";
      version = "0.2.35";
      src = pkgs.fetchurl {
        url = "https://github.com/zackb/tether/releases/download/v${version}/tether-${version}-x86_64.AppImage";
        hash = "sha256-T3vAZaouasv/kiuCWXWVFCDOpKu3HM8y8oqSXJj+kMk=";
      };
      appimageContents = pkgs.appimageTools.extract {
        inherit pname version src;
      };
    in
    pkgs.appimageTools.wrapType2 {
      inherit pname version src;

      extraInstallCommands = ''
        install -Dm444 ${appimageContents}/tether-gtk.desktop \
          $out/share/applications/tether-gtk.desktop
        substituteInPlace $out/share/applications/tether-gtk.desktop \
          --replace-fail 'Exec=tether-gtk' "Exec=$out/bin/tether"
        cp -R ${appimageContents}/usr/share/icons $out/share/
        chmod u+w $out/share/icons/hicolor
        rm -f $out/share/icons/hicolor/icon-theme.cache
      '';

      meta = {
        description = "Bridge an iPhone to the Linux desktop";
        homepage = "https://github.com/zackb/tether";
        license = lib.licenses.mit;
        mainProgram = "tether";
        platforms = [ "x86_64-linux" ];
        sourceProvenance = with lib.sourceTypes; [ binaryNativeCode ];
      };
    };

  zed = pkgs.stdenvNoCC.mkDerivation rec {
    pname = "zed-editor";
    version = "1.22.0";

    nativeBuildInputs = [
      pkgs.autoPatchelfHook
      pkgs.makeWrapper
    ];
    buildInputs = [
      pkgs.alsa-lib
      pkgs.glib
    ];
    runtimeDependencies = map lib.getLib [
      pkgs.libGL
      pkgs.vulkan-loader
      pkgs.wayland
    ];

    postFixup = ''
      wrapProgram "$out/libexec/zed-editor" \
        --set XKB_CONFIG_ROOT "${pkgs.xkeyboard_config}/share/X11/xkb" \
        --set XLOCALEDIR "${pkgs.libx11}/share/X11/locale"
    '';

    src = pkgs.fetchurl {
      url = "https://github.com/zed-industries/zed/releases/download/v${version}/zed-linux-x86_64.tar.gz";
      hash = "sha256-XOOZGzSo+tCiNiX1ghzaYBxxUKbMaWg8CXuNGwg6vFA=";
    };

    installPhase = ''
      runHook preInstall
      mkdir -p "$out"
      cp -R ./. "$out/"
      substituteInPlace "$out/share/applications/dev.zed.Zed.desktop" \
        --replace-fail 'Exec=zed' "Exec=$out/bin/zed"
      runHook postInstall
    '';

    meta = {
      description = "High-performance multiplayer code editor";
      homepage = "https://zed.dev/";
      license = lib.licenses.gpl3Only;
      mainProgram = "zed";
      platforms = [ "x86_64-linux" ];
      sourceProvenance = with lib.sourceTypes; [ binaryNativeCode ];
    };
  };
in
{
  inherit
    buzz
    codex
    herdr
    localsend
    tether
    terraform
    zed
    ;
}
