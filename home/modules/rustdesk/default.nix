{ config, lib, pkgs, ... }:
let
  cfg = config.modules.rustdesk;
  data = pkgs.runCommand "rustdesk-homelab-profile" { nativeBuildInputs = [ pkgs.python3 ]; } ''
    mkdir -p "$out"
    cp ${./profile.json} "$out/profile.json"
    cp ${./clients.json} "$out/clients.json"
    python ${./client.py} --directory "$out" config > "$out/server-config.txt"
  '';
in
{
  options.modules.rustdesk.enable = lib.mkEnableOption "homelab RustDesk server profile and qualified connections";
  config = lib.mkIf cfg.enable {
    xdg.configFile."rustdesk-homelab".source = data;
    home.packages = [ (pkgs.writeShellScriptBin "rustdesk-homelab" ''
      exec ${pkgs.python3}/bin/python ${./client.py} --directory ${data} "$@"
    '') ];
  };
}
