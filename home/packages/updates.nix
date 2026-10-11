{ inputs }:
final: prev:
let
  inherit (final) lib;
  system = final.stdenv.hostPlatform.system;
  latestPkgs = import inputs.nixpkgs-updates {
    inherit system;
    config.allowUnfree = true;
  };

  # Use official release binaries until nixos-unstable catches up.
  # Remove the corresponding override once the channel provides this version.
  mkReleaseBinary = { package, version, releases, format, executable ? package.meta.mainProgram }:
    let
      release = releases.${system};
      binary = final.stdenvNoCC.mkDerivation {
        inherit (package) pname;
        inherit version;
        src = final.fetchurl { inherit (release) url hash; };
        dontUnpack = true;
        nativeBuildInputs = [ final.makeWrapper ];
        installPhase = ''
          runHook preInstall
          mkdir -p "$out/bin"
        '' + (if (release.format or format) == "raw" then ''
          install -m755 "$src" "$out/bin/${executable}"
        '' else if (release.format or format) == "gzip" then ''
          gzip -dc "$src" > "$out/bin/${executable}"
          chmod +x "$out/bin/${executable}"
        '' else ''
          mkdir extracted
          tar -xf "$src" -C extracted
          binary=$(find extracted -type f -name ${lib.escapeShellArg executable} -print -quit)
          test -n "$binary"
          install -m755 "$binary" "$out/bin/${executable}"
          if [ -d extracted/mise/share ]; then
            cp -R extracted/mise/share "$out/share"
          fi
          if [ -d extracted/mise/man ]; then
            mkdir -p "$out/share/man"
            cp -R extracted/mise/man/. "$out/share/man/"
          fi
        '') + lib.optionalString (executable == "direnv") ''
          wrapProgram "$out/bin/direnv" --set DIRENV_BASH ${final.bash}/bin/bash
        '' + lib.optionalString (executable == "mise") ''
          mkdir -p "$out/lib/mise"
          touch "$out/lib/mise/.disable-self-update"
        '' + ''
          runHook postInstall
        '';
        meta = package.meta // {
          sourceProvenance = [ lib.sourceTypes.binaryNativeCode ];
        };
      };
    in
    binary;
in
{
  inherit (latestPkgs) nushell tailscale;

  atuin = mkReleaseBinary {
    package = prev.atuin;
    version = "18.23.0";
    format = "tar";
    executable = "atuin";
    releases = {
      x86_64-linux = {
        url = "https://github.com/atuinsh/atuin/releases/download/v18.23.0/atuin-x86_64-unknown-linux-musl.tar.gz";
        hash = "sha256-0bQN1ufNPYI4Z//iKzmgJbxCD3h1kmrpypdBVTeNoU0=";
      };
      aarch64-darwin = {
        url = "https://github.com/atuinsh/atuin/releases/download/v18.23.0/atuin-aarch64-apple-darwin.tar.gz";
        hash = "sha256-yYi+HN4ZzXKVzmS8i5VdQvsYVeUifLZAyH/AnIQIw/w=";
      };
    };
  };

  mise = mkReleaseBinary {
    package = prev.mise;
    version = "2026.10.7";
    format = "tar";
    executable = "mise";
    releases = {
      x86_64-linux = {
        url = "https://github.com/jdx/mise/releases/download/v2026.10.7/mise-v2026.10.7-linux-x64-musl.tar.xz";
        hash = "sha256-sndSDBzko9QwSRrUaAJL0MsKAjKP0Us1JKyESTo71+Y=";
      };
      aarch64-darwin = {
        url = "https://github.com/jdx/mise/releases/download/v2026.10.7/mise-v2026.10.7-macos-arm64.tar.xz";
        hash = "sha256-7KkcfXmHPAb+X6CFYrP/NKUm3T+UuUU5GmHba1SBszU=";
      };
    };
  };

  direnv = mkReleaseBinary {
    package = prev.direnv;
    version = "2.38.2";
    format = "raw";
    executable = "direnv";
    releases = {
      x86_64-linux = {
        url = "https://github.com/direnv/direnv/releases/download/v2.38.2/direnv.linux-amd64";
        hash = "sha256-FIggoYeTDTbKaiBFBOXNsw2Dls0al+ZMOz8Q15PBEkc=";
      };
      aarch64-darwin = {
        url = "https://github.com/direnv/direnv/releases/download/v2.38.2/direnv.darwin-arm64";
        hash = "sha256-MEQ8QT50YUpT3rkCNOnJdmGxBBoPSspgHOtIKleK6LY=";
      };
    };
  };

  lefthook = mkReleaseBinary {
    package = prev.lefthook;
    version = "2.2.1";
    format = "gzip";
    executable = "lefthook";
    releases = {
      x86_64-linux = {
        url = "https://github.com/evilmartians/lefthook/releases/download/v2.2.1/lefthook_2.2.1_Linux_x86_64.gz";
        hash = "sha256-Gw/zMgn7McXac6a4YMUHetg7HYqZ5G9QMfwU7pbK+f4=";
      };
      aarch64-darwin = {
        url = "https://github.com/evilmartians/lefthook/releases/download/v2.2.1/lefthook_2.2.1_MacOS_arm64.gz";
        hash = "sha256-xYrL2fqyEbYpGgwx2W1/EuC0IOEpiSEq8hk+e8f0oxk=";
      };
    };
  };

  cloudflared = mkReleaseBinary {
    package = prev.cloudflared;
    version = "2026.10.0";
    format = "raw";
    executable = "cloudflared";
    releases = {
      x86_64-linux = {
        url = "https://github.com/cloudflare/cloudflared/releases/download/2026.10.0/cloudflared-linux-amd64";
        hash = "sha256-0z/y0UR1F40gEsLFa+uoc4msXe0nZJUZ8Zin0xNKmds=";
      };
      aarch64-darwin = {
        url = "https://github.com/cloudflare/cloudflared/releases/download/2026.10.0/cloudflared-darwin-arm64.tgz";
        hash = "sha256-ovef97lCCqU310ryOfN22hcLur61Ka7EFgAq2sanLnA=";
        format = "tar";
      };
    };
  };

  vscode = prev.vscode.overrideAttrs (old: {
    version = "1.141.0";
    passthru = old.passthru // {
      vscodeVersion = "1.141.0";
      rev = "2a59476c9bfcb90b3ddc372c36762471b7dfad1c";
      vscodeServer = final.fetchurl {
        name = "vscode-server-2a59476c9bfcb90b3ddc372c36762471b7dfad1c.tar.gz";
        url = "https://update.code.visualstudio.com/commit:2a59476c9bfcb90b3ddc372c36762471b7dfad1c/server-linux-x64/stable";
        hash = "sha256-VxHtJpDlUNUsqFMbzTSeJz7XtOCyIYB2epM4/Vct4ro=";
      };
    };
    src = final.fetchurl {
      name = "VSCode_1.141.0_${system}.${if final.stdenv.hostPlatform.isDarwin then "zip" else "tar.gz"}";
      url = "https://update.code.visualstudio.com/1.141.0/${if final.stdenv.hostPlatform.isDarwin then "darwin-arm64" else "linux-x64"}/stable";
      hash = {
        x86_64-linux = "sha256-131YjwRUy6qnHnI0l95BYNFblfukmIq+F3sUMua9Vwo=";
        aarch64-darwin = "sha256-m0rjhuPPc417qZAjfd8KGAkskkobyuRl7UaXlkdF9C0=";
      }.${system};
    };
  });

  neovim-unwrapped = prev.neovim-unwrapped.overrideAttrs (_: {
    version = "0.12.6";
    src = final.fetchzip {
      url = "https://codeload.github.com/neovim/neovim/tar.gz/refs/tags/v0.12.6";
      extension = "tar.gz";
      hash = "sha256-lK1gbJyESMN3C/i8cyPFzzlJDYZHzEXugGhCwPVEbNk=";
    };
  });

  telegram-desktop = if final.stdenv.hostPlatform.isLinux then
    final.stdenvNoCC.mkDerivation {
      pname = "telegram-desktop";
      version = "7.3.1";
      src = final.fetchurl {
        url = "https://github.com/telegramdesktop/tdesktop/releases/download/v7.3.1/td-setup-linux-x64-7.3.1.tar.xz";
        hash = "sha256-ZUpbJm1lOwcrRAekZEvUQeN+45P1AscbLh2G/BFbirY=";
      };
      # patchelf 0.15 moves .init without fixing Telegram's startup call.
      nativeBuildInputs = [ final.patchelfUnstable final.autoPatchelfHook final.makeWrapper ];
      buildInputs = with final; [
        stdenv.cc.cc.lib alsa-lib cairo dbus fontconfig freetype glib libglvnd
        libpulseaudio pango pipewire
        libx11 libxcb libxcomposite libxcursor libxdamage libxext
        libxfixes libxrandr libxrender libxtst libxkbcommon zlib
      ];
      runtimeDependencies = map lib.getLib [
        final.libGL final.wayland final.libxkbcommon final.libx11 final.gtk3
      ];
      installPhase = ''
        runHook preInstall
        install -Dm755 Telegram "$out/libexec/Telegram"
        cp -R ${prev.telegram-desktop}/share "$out/share"
        chmod -R u+w "$out/share"
        mkdir -p "$out/bin"
        makeWrapper "$out/libexec/Telegram" "$out/bin/telegram-desktop" --add-flags -noupdate
        ln -s "$out/bin/telegram-desktop" "$out/bin/Telegram"
        substituteInPlace "$out/share/applications/org.telegram.desktop.desktop" \
          --replace-fail 'Exec=Telegram' "Exec=$out/bin/telegram-desktop"
        runHook postInstall
      '';
      meta = prev.telegram-desktop.meta // {
        platforms = [ "x86_64-linux" ];
        sourceProvenance = [ lib.sourceTypes.binaryNativeCode ];
      };
    }
  else prev.telegram-desktop;
}
