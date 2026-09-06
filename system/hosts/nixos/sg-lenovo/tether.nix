{ pkgs, ... }:

{
  # Tether needs BlueZ's experimental LE bearer API before the iPhone is paired.
  hardware.bluetooth.settings.General.Experimental = true;

  # bluetoothd resets the adapter class whenever it starts. Keep hci0 advertised
  # as A/V Hands-Free so iOS exposes MAP/PBAP permissions for Tether.
  systemd.services."tether-btclass@hci0" = {
    description = "Set Bluetooth Class of Device for Tether on hci0";
    documentation = [ "https://github.com/zackb/tether/blob/main/docs/BLUETOOTH.md" ];
    after = [ "bluetooth.service" ];
    partOf = [ "bluetooth.service" ];
    wantedBy = [ "bluetooth.service" ];

    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
      ExecStart = pkgs.writeShellScript "tether-btclass-hci0" ''
        for attempt in 1 2 3 4 5 6 7 8 9 10; do
          echo | ${pkgs.bluez}/bin/btmgmt --index hci0 class 4 8 >/dev/null 2>&1
          if echo | ${pkgs.bluez}/bin/btmgmt --index hci0 info 2>/dev/null \
            | ${pkgs.gnugrep}/bin/grep -q "class 0x..0408"; then
            exit 0
          fi
          ${pkgs.coreutils}/bin/sleep 1
        done
        exit 1
      '';
      TimeoutStartSec = 60;
    };
  };
}
