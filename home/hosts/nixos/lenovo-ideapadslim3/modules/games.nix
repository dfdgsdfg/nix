{ config, lib, pkgs, ... }:

let
  gamesPath = "${config.home.homeDirectory}/games";
  romsPath = "${gamesPath}/roms";
  heroicPath = "${gamesPath}/heroic";
  doomPath = "${gamesPath}/doom";

  beyondAllReasonFonts = pkgs.writeTextDir "etc/fonts/fonts.conf" ''
    <?xml version="1.0" encoding="UTF-8"?>
    <!DOCTYPE fontconfig SYSTEM "urn:fontconfig:fonts.dtd">
    <fontconfig>
      <dir>${pkgs.dejavu_fonts}/share/fonts</dir>
      <dir>${pkgs.liberation_ttf}/share/fonts</dir>
      <cachedir>${config.home.homeDirectory}/.cache/fontconfig</cachedir>
    </fontconfig>
  '';

  beyondAllReasonWrapped = pkgs.symlinkJoin {
    name = "beyond-all-reason-wrapped";
    paths = [ pkgs.beyond-all-reason ];
    nativeBuildInputs = [ pkgs.makeWrapper ];
    postBuild = ''
      rm $out/bin/beyond-all-reason
      makeWrapper ${pkgs.beyond-all-reason}/bin/beyond-all-reason $out/bin/beyond-all-reason \
        --set FONTCONFIG_FILE ${beyondAllReasonFonts}/etc/fonts/fonts.conf \
        --set FONTCONFIG_PATH ${beyondAllReasonFonts}/etc/fonts
    '';
  };

  openhv =
    let
      pname = "openhv";
      version = "20250725";
      src = pkgs.fetchurl {
        url = "https://github.com/OpenHV/OpenHV/releases/download/${version}/OpenHV-${version}-x86_64.AppImage";
        hash = "sha256-AbG/HPhlAPYdgz4iBVoDXlbQez3byDuRRG1oSzWSGqM=";
      };
      appimageContents = pkgs.appimageTools.extractType2 {
        inherit pname version src;
      };
    in
    pkgs.appimageTools.wrapType2 {
      inherit pname version src;

      extraPkgs = pkgs: with pkgs; [
        icu
      ];

      extraInstallCommands = ''
        install -Dm444 ${appimageContents}/openhv.desktop $out/share/applications/openhv.desktop
        install -Dm444 ${appimageContents}/openhv.png $out/share/icons/hicolor/256x256/apps/openhv.png
      '';

      meta = {
        description = "Open source pixel art science-fiction real-time strategy game";
        homepage = "https://www.openhv.net/";
        license = lib.licenses.gpl3Only;
        mainProgram = "openhv";
        platforms = [ "x86_64-linux" ];
        sourceProvenance = with lib.sourceTypes; [ binaryNativeCode ];
      };
    };

  opemux =
    let
      pythonEnv = pkgs.python3.withPackages (pythonPackages: with pythonPackages; [
        pycairo
        pygobject3
        pyyaml
      ]);
      gsettingsDataDirs = lib.concatStringsSep ":" [
        "${pkgs.gtk4}/share/gsettings-schemas/${pkgs.gtk4.name}"
        "${pkgs.libadwaita}/share/gsettings-schemas/${pkgs.libadwaita.name}"
        "${pkgs.gsettings-desktop-schemas}/share/gsettings-schemas/${pkgs.gsettings-desktop-schemas.name}"
        "${pkgs.gtk4}/share"
        "${pkgs.libadwaita}/share"
        "${pkgs.adwaita-icon-theme}/share"
        "${pkgs.shared-mime-info}/share"
      ];
    in
    pkgs.stdenvNoCC.mkDerivation {
      pname = "opemux";
      version = "unstable-2026-02-21";

      src = pkgs.fetchFromGitHub {
        owner = "guilhermefeitosa66";
        repo = "opemux";
        rev = "38c3dbf735db0a1d9e09d5c990e314f464b5598c";
        hash = "sha256-CplO0lhny8sQjQgg0SA4bJk7vTLcXNa6Iso8R8qo8xE=";
      };

      nativeBuildInputs = [ pkgs.makeWrapper ];
      dontBuild = true;

      installPhase = ''
        runHook preInstall

        mkdir -p $out/bin $out/share/applications $out/share/opemux $out/share/pixmaps
        cp -R . $out/share/opemux

        substituteInPlace $out/share/opemux/src/opemux/core/config.py \
          --replace-fail 'vendors/RetroArch-Linux-x86_64.AppImage' 'retroarch'
        substituteInPlace $out/share/opemux/src/opemux/main.py \
          --replace-fail '        _ensure_desktop_integration()' '        pass  # Desktop integration is managed by Home Manager.'

        cp docs/assets/logo.png $out/share/pixmaps/org.opemux.Opemux.png

        makeWrapper ${pythonEnv}/bin/python3 $out/bin/opemux \
          --add-flags "$out/share/opemux/src/opemux/main.py" \
          --set OPEMUX_PROJECT_ROOT "$out/share/opemux" \
          --set PYTHONPATH "$out/share/opemux/src" \
          --prefix PATH : "${lib.makeBinPath [ pkgs.retroarch pkgs.xdg-utils ]}" \
          --prefix GI_TYPELIB_PATH : "${lib.makeSearchPath "lib/girepository-1.0" [
            pkgs.gtk4
            pkgs.libadwaita
            pkgs.gdk-pixbuf
            pkgs.pango
            pkgs.harfbuzz
            pkgs.graphene
            pkgs.glib
          ]}" \
          --prefix XDG_DATA_DIRS : "${gsettingsDataDirs}"

        printf '%s\n' \
          '[Desktop Entry]' \
          'Type=Application' \
          'Name=Opemux' \
          'Comment=Linux-native emulation frontend for RetroArch' \
          "Exec=$out/bin/opemux" \
          'Icon=org.opemux.Opemux' \
          'Categories=Game;Emulator;' \
          'Terminal=false' \
          'StartupWMClass=org.opemux.Opemux' \
          > $out/share/applications/org.opemux.Opemux.desktop

        runHook postInstall
      '';

      meta = {
        description = "Linux-native emulation frontend for RetroArch";
        homepage = "https://github.com/guilhermefeitosa66/opemux";
        license = lib.licenses.mit;
        mainProgram = "opemux";
        platforms = lib.platforms.linux;
      };
    };

  doomrunnerWrapped = pkgs.symlinkJoin {
    name = "doomrunner-wrapped";
    paths = [ pkgs.doomrunner ];
    nativeBuildInputs = [ pkgs.makeWrapper ];
    postBuild = ''
      rm $out/bin/DoomRunner
      makeWrapper ${pkgs.doomrunner}/bin/DoomRunner $out/bin/DoomRunner \
        --prefix XDG_DATA_DIRS : "${pkgs.gtk3}/share/gsettings-schemas/${pkgs.gtk3.name}:${pkgs.gsettings-desktop-schemas}/share/gsettings-schemas/${pkgs.gsettings-desktop-schemas.name}"
    '';
  };

  heroicWithNativeLibraries = pkgs.heroic.override {
    extraLibraries = pkgs: with pkgs; [
      gamemode.lib
      libGLU
      libxcursor
      libxrandr
    ];
  };

  heroicSyncGogGenres = pkgs.writeShellApplication {
    name = "heroic-sync-gog-genres";
    text = ''
      exec ${pkgs.python3}/bin/python3 ${../../../../scripts/heroic-sync-gog-genres.py} "$@"
    '';
  };
in
{
  home.packages = with pkgs; [
    beyondAllReasonWrapped
    doomrunnerWrapped
    dosbox-x
    heroicWithNativeLibraries
    heroicSyncGogGenres
    openhv
    opemux
    scummvm
    uzdoom
    (retroarch.withCores (cores: with cores; [
      genesis-plus-gx
      snes9x
      beetle-psx-hw
    ]))
  ];

  home.file.".local/share/applications/org.opemux.Opemux.desktop" = {
    force = true;
    source = "${opemux}/share/applications/org.opemux.Opemux.desktop";
  };

  home.activation.shareRomsBetweenRetroarchAndOpemux = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    roms_path="${romsPath}"
    mkdir -p "$roms_path"
    mkdir -p "$HOME/.opemux" "$HOME/.config/retroarch"

    ${pkgs.python3.withPackages (pythonPackages: [ pythonPackages.pyyaml ])}/bin/python3 - "$roms_path" <<'PY'
import sys
from pathlib import Path

import yaml

roms_path = sys.argv[1]
config_path = Path.home() / ".opemux" / "config.yaml"

if config_path.exists():
    with config_path.open("r", encoding="utf-8") as f:
        config = yaml.safe_load(f) or {}
else:
    config = {}

config["roms_path"] = roms_path
runtime = config.setdefault("runtime", {})
retroarch = runtime.setdefault("retroarch", {})
retroarch["binary"] = "retroarch"

with config_path.open("w", encoding="utf-8") as f:
    yaml.safe_dump(config, f, sort_keys=False)
PY

    retroarch_cfg="$HOME/.config/retroarch/retroarch.cfg"
    touch "$retroarch_cfg"

    set_retroarch_cfg() {
      key="$1"
      value="$2"
      if grep -q "^$key = " "$retroarch_cfg"; then
        ${pkgs.gnused}/bin/sed -i "s|^$key = .*|$key = \"$value\"|" "$retroarch_cfg"
      else
        printf '%s = "%s"\n' "$key" "$value" >> "$retroarch_cfg"
      fi
    }

    set_retroarch_cfg rgui_browser_directory "$roms_path"
    set_retroarch_cfg use_last_start_directory false
  '';

  home.activation.configureDoomPaths = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    doom_path="${doomPath}"
    mkdir -p \
      "$doom_path" \
      "$doom_path/iwads" \
      "$doom_path/pwads" \
      "$doom_path/pwads-graphics" \
      "$doom_path/pwads-maps" \
      "$doom_path/pwads-music" \
      "$doom_path/sourceports" \
      "$HOME/.local/share/DoomRunner" \
      "$HOME/.config/uzdoom"

    rewrite_doom_json_path() {
      json_path="$1"
      if [ -s "$json_path" ] && ${pkgs.jq}/bin/jq empty "$json_path" >/dev/null 2>&1; then
        tmp="$(${pkgs.coreutils}/bin/mktemp)"
        ${pkgs.jq}/bin/jq \
          --arg old_games "$HOME/Games" \
          --arg new_games "${gamesPath}" \
          'def rewrite_string:
            if . == $old_games then $new_games
            elif startswith($old_games + "/") then $new_games + (.[$old_games|length:])
            else .
            end;
          def rewrite_paths:
            if type == "object" then with_entries(.key |= rewrite_string | .value |= rewrite_paths)
            elif type == "array" then map(rewrite_paths)
            elif type == "string" then rewrite_string
            else .
            end;
          rewrite_paths' \
          "$json_path" > "$tmp"
        ${pkgs.coreutils}/bin/mv "$tmp" "$json_path"
      fi
    }

    options_path="$HOME/.local/share/DoomRunner/options.json"
    rewrite_doom_json_path "$options_path"
    if [ -s "$options_path" ] && ${pkgs.jq}/bin/jq empty "$options_path" >/dev/null 2>&1; then
      tmp="$(${pkgs.coreutils}/bin/mktemp)"
      ${pkgs.jq}/bin/jq \
        --arg doom_path "$doom_path" \
        --arg iwads_path "$doom_path/iwads" \
        --arg uzdoom_path "$HOME/.config/uzdoom" \
        --arg uzdoom_bin "$HOME/.nix-profile/bin/uzdoom" \
        '.IWADs.directory = $iwads_path
         | .maps.directory = $doom_path
         | .engines.engine_list = ((.engines.engine_list // []) | map(
             if .name == "uzdoom" then
               .config_dir = $uzdoom_path
               | .data_dir = $uzdoom_path
               | .path = $uzdoom_bin
             else .
             end
           ))' \
        "$options_path" > "$tmp"
      ${pkgs.coreutils}/bin/mv "$tmp" "$options_path"
    fi

    rewrite_doom_json_path "$HOME/.local/share/DoomRunner/file_info_cache.json"

    uzdoom_ini="$HOME/.config/uzdoom/uzdoom.ini"
    if [ -e "$uzdoom_ini" ]; then
      ${pkgs.gnused}/bin/sed -i \
        -e 's|[$]HOME/Games/doom|$HOME/games/doom|g' \
        -e 's|[$]HOME/Games/Heroic|$HOME/games/heroic|g' \
        -e "s|${config.home.homeDirectory}/Games/doom|${doomPath}|g" \
        -e "s|${config.home.homeDirectory}/Games/Heroic|${heroicPath}|g" \
        "$uzdoom_ini"
    fi

    if [ -e "$HOME/.config/QtProject.conf" ]; then
      ${pkgs.gnused}/bin/sed -i \
        -e "s|file://$HOME/Games|file://$HOME/games|g" \
        -e "s|$HOME/Games|$HOME/games|g" \
        "$HOME/.config/QtProject.conf"
    fi

    if [ -e "$HOME/.config/gtk-3.0/bookmarks" ]; then
      ${pkgs.gnused}/bin/sed -i \
        -e "s|file://$HOME/Games|file://$HOME/games|g" \
        "$HOME/.config/gtk-3.0/bookmarks"
    fi
  '';

  home.activation.configureHeroicPaths = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    heroic_path="${heroicPath}"
    mkdir -p "$heroic_path" "$HOME/.config/heroic/store"

    rewrite_heroic_json_path() {
      json_path="$1"
      if [ -s "$json_path" ] && ${pkgs.jq}/bin/jq empty "$json_path" >/dev/null 2>&1; then
        tmp="$(${pkgs.coreutils}/bin/mktemp)"
        ${pkgs.jq}/bin/jq \
          --arg old_path "$HOME/Games/Heroic" \
          --arg new_path "$heroic_path" \
          'walk(if type == "string" then
            if . == $old_path then $new_path
            elif startswith($old_path + "/") then $new_path + (.[$old_path|length:])
            else .
            end
          else .
          end)' \
          "$json_path" > "$tmp"
        ${pkgs.coreutils}/bin/mv "$tmp" "$json_path"
      fi
    }

    disable_heroic_steam_runtime() {
      json_path="$1"
      if [ -s "$json_path" ] && ${pkgs.jq}/bin/jq empty "$json_path" >/dev/null 2>&1; then
        tmp="$(${pkgs.coreutils}/bin/mktemp)"
        ${pkgs.jq}/bin/jq \
          'walk(if type == "object" and has("useSteamRuntime") then
            .useSteamRuntime = false
          else .
          end)' \
          "$json_path" > "$tmp"
        ${pkgs.coreutils}/bin/mv "$tmp" "$json_path"
      fi
    }

    set_heroic_defaults() {
      config_path="$1"
      settings_key="$2"
      if [ -s "$config_path" ] && ${pkgs.jq}/bin/jq empty "$config_path" >/dev/null 2>&1; then
        tmp="$(${pkgs.coreutils}/bin/mktemp)"
        ${pkgs.jq}/bin/jq \
          --arg settings_key "$settings_key" \
          --arg install_path "$heroic_path" \
          --arg wine_prefix "$heroic_path/Prefixes/default" \
          '.[$settings_key] = (.[$settings_key] // {})
           | .[$settings_key].defaultInstallPath = $install_path
           | .[$settings_key].defaultWinePrefix = $wine_prefix
           | .[$settings_key].defaultWinePrefixDir = $wine_prefix
           | .[$settings_key].winePrefix = $wine_prefix
           | .[$settings_key].useSteamRuntime = false' \
          "$config_path" > "$tmp"
        ${pkgs.coreutils}/bin/mv "$tmp" "$config_path"
      fi
    }

    config_path="$HOME/.config/heroic/store/config.json"
    rewrite_heroic_json_path "$config_path"
    if [ -s "$config_path" ] && ${pkgs.jq}/bin/jq empty "$config_path" >/dev/null 2>&1; then
      tmp="$(${pkgs.coreutils}/bin/mktemp)"
      ${pkgs.jq}/bin/jq \
        --arg install_path "$heroic_path" \
        --arg wine_prefix "$heroic_path/Prefixes/default" \
        '.settings = (.settings // {})
         | .settings.defaultInstallPath = $install_path
         | .settings.defaultWinePrefix = $wine_prefix
         | .settings.winePrefix = $wine_prefix
         | .settings.useSteamRuntime = false' \
        "$config_path" > "$tmp"
      ${pkgs.coreutils}/bin/mv "$tmp" "$config_path"
    fi

    legacy_config_path="$HOME/.config/heroic/config.json"
    rewrite_heroic_json_path "$legacy_config_path"
    set_heroic_defaults "$legacy_config_path" defaultSettings
    disable_heroic_steam_runtime "$legacy_config_path"

    rewrite_heroic_json_path "$HOME/.config/heroic/store/download-manager.json"
    rewrite_heroic_json_path "$HOME/.config/heroic/gog_store/installed.json"

    for game_config_path in "$HOME"/.config/heroic/GamesConfig/*.json; do
      [ -e "$game_config_path" ] || continue
      rewrite_heroic_json_path "$game_config_path"
      disable_heroic_steam_runtime "$game_config_path"
    done
  '';

  # nixpkgs.overlays = [
  #   (final: prev: {
  #     retroarch-bare = prev.retroarch-bare.overrideAttrs (old: {
  #       patches = (old.patches or [ ]) ++ [
  #         (final.fetchpatch {
  #           url = "https://github.com/libretro/RetroArch/commit/2bc0a25e6f5cf2b67b183792886e24c2ec5d448e.patch";
  #           sha256 = "sha256-gkpBql5w/xUpddv/6sePb5kZ5gy9huStDthmvoz6Qbk=";
  #         })
  #       ];
  #     });
  #   })
  # ];
  # programs.gamescope.enable = true;
  # programs.gamemode.enable = true;
}
