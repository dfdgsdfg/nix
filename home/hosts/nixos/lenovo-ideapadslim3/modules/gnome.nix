{ pkgs, ... }:

let
  autoMoveWindowsUuid = "auto-move-windows@gnome-shell-extensions.gcampax.github.com";
  lidIdleInhibitor = pkgs.writeShellApplication {
    name = "lid-idle-inhibitor";
    runtimeInputs = with pkgs; [
      coreutils
      gnugrep
      gnome-session
    ];
    text = ''
      lid_state_file="/proc/acpi/button/lid/LID0/state"
      inhibitor_pid=""

      stop_inhibitor() {
        if [[ -n "$inhibitor_pid" ]] && kill -0 "$inhibitor_pid" 2>/dev/null; then
          kill "$inhibitor_pid"
          wait "$inhibitor_pid" 2>/dev/null || true
        fi
        inhibitor_pid=""
      }

      cleanup() {
        stop_inhibitor
      }
      trap cleanup EXIT INT TERM

      if [[ ! -r "$lid_state_file" ]]; then
        printf 'Cannot read lid state: %s\n' "$lid_state_file" >&2
        exit 1
      fi

      while true; do
        if grep --quiet 'closed' "$lid_state_file"; then
          if [[ -z "$inhibitor_pid" ]] || ! kill -0 "$inhibitor_pid" 2>/dev/null; then
            gnome-session-inhibit \
              --app-id=dev.dididi.LidIdleInhibitor \
              --reason='Keep the logged-in GNOME session available while the lid is closed' \
              --inhibit=idle \
              --inhibit-only &
            inhibitor_pid=$!
          fi
        else
          stop_inhibitor
        fi

        sleep 2
      done
    '';
  };
in
{
  home.packages = with pkgs; [
    gnomeExtensions.auto-move-windows
  ];

  home.file.".local/share/gnome-shell/extensions/${autoMoveWindowsUuid}".source =
    "${pkgs.gnomeExtensions.auto-move-windows}/share/gnome-shell/extensions/${autoMoveWindowsUuid}";

  systemd.user.services.lid-idle-inhibitor = {
    Unit = {
      Description = "Inhibit GNOME idle locking while the laptop lid is closed";
      PartOf = [ "graphical-session.target" ];
      After = [ "graphical-session.target" ];
    };
    Service = {
      ExecStart = "${lidIdleInhibitor}/bin/lid-idle-inhibitor";
      Restart = "on-failure";
      RestartSec = 2;
    };
    Install.WantedBy = [ "graphical-session.target" ];
  };

  dconf.settings = {
    "org/gnome/shell" = {
      enabled-extensions = [
        autoMoveWindowsUuid
      ];
      disabled-extensions = [ ];
    };

    "org/gnome/shell/extensions/auto-move-windows" = {
      application-list = [
        "com.seance.app.desktop:2"
        "zen-beta.desktop:3"
        "discord-ptb.desktop:4"
      ];
    };

    # Keep GNOME from suspending while on AC power. Battery behavior is left
    # unchanged, so the existing battery suspend policy still applies.
    "org/gnome/settings-daemon/plugins/power" = {
      sleep-inactive-ac-type = "nothing";
    };
  };
}
