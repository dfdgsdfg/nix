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

  herdr = mkRawBinary {
    pname = "herdr";
    version = "0.8.2";
    releases = {
      x86_64-linux = {
        url = "https://github.com/herdrdev/herdr/releases/download/v0.8.2/herdr-linux-x86_64";
        hash = "sha256-l2FQoU1JDJSyQ+ouGn6y37Z/EuNrGC25CTb2co5q7PQ=";
      };
      aarch64-darwin = {
        url = "https://github.com/herdrdev/herdr/releases/download/v0.8.2/herdr-macos-aarch64";
        hash = "sha256-pdT01QTYswnJH4EQUFWTAPq6MSWEJfU8UIUvyW9q5XQ=";
      };
    };
    description = "Terminal UI for managing coding agents";
    homepage = "https://github.com/herdrdev/herdr";
    license = lib.licenses.mit;
  };

  terraformRelease = selectRelease "terraform" {
    x86_64-linux = {
      asset = "linux_amd64";
      hash = "sha256-du3Qsi0vJ9PS4JfNeTIJZG9xnPYPAv869iawc2ETfaE=";
    };
    aarch64-darwin = {
      asset = "darwin_arm64";
      hash = "sha256-BbJ1hqXX2EEFaQ7MzH7bv0i8PW1Xd0XLYfFjupkK308=";
    };
  };
  terraform = pkgs.stdenvNoCC.mkDerivation rec {
    pname = "terraform";
    version = "1.15.9";

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
      hash = "sha256-HAi6Jiggt41J6nqT8ya2tDC3Ll/kaDDkM+3vEuUSMkQ=";
    };
    aarch64-darwin = {
      target = "aarch64-apple-darwin";
      hash = "sha256-bHWJpS/pDjdC41ZiEVpMVcOXFWAd8NQTRbqOyPQiHU4=";
    };
  };
  codex = pkgs.stdenvNoCC.mkDerivation rec {
    pname = "codex";
    version = "0.149.0";

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

  opencode = pkgs.stdenvNoCC.mkDerivation rec {
    pname = "opencode";
    version = "1.18.21";

    src = pkgs.fetchurl {
      url = "https://github.com/anomalyco/opencode/releases/download/v${version}/opencode-linux-x64.tar.gz";
      hash = "sha256-2RDD7XYTu1eRoyiQRhXUHMJbfTprRw4xmasEJqmVs4o=";
    };

    dontUnpack = true;

    installPhase = ''
      runHook preInstall
      tar -xzf "$src"
      install -Dm755 opencode "$out/bin/opencode"
      runHook postInstall
    '';

    meta = {
      description = "Open source coding agent";
      homepage = "https://opencode.ai/";
      license = lib.licenses.mit;
      mainProgram = "opencode";
      platforms = [ "x86_64-linux" ];
      sourceProvenance = with lib.sourceTypes; [ binaryNativeCode ];
    };
  };

  localsend =
    let
      pname = "localsend";
      version = "1.18.0";
      src = pkgs.fetchurl {
        url = "https://github.com/localsend/localsend/releases/download/v${version}/LocalSend-${version}-linux-x86-64.AppImage";
        hash = "sha256-yHO9FID5dW4RfMymaKaYvtnlBkR4hAWafTfV1k+2X+I=";
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

  zed = pkgs.stdenvNoCC.mkDerivation rec {
    pname = "zed-editor";
    version = "1.16.1";

    src = pkgs.fetchurl {
      url = "https://github.com/zed-industries/zed/releases/download/v${version}/zed-linux-x86_64.tar.gz";
      hash = "sha256-nmEa3QxA6GsVA3JFii17eNEBxUkk3HvKjbJ84g2XxmE=";
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
    codex
    herdr
    localsend
    opencode
    terraform
    zed
    ;
}
