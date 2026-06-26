{ config, lib, pkgs, ... }:

{
  programs.fish = {
    enable = true;
    interactiveShellInit = ''
      set fish_greeting # Disable greeting
    '';
    plugins = [
      # Enable a plugin (here grc for colorized command output) from nixpkgs
      { name = "grc"; src = pkgs.fishPlugins.grc.src; }
      # Manually packaging and enable a plugin
      # {
      #   name = "z";
      #   src = pkgs.fetchFromGitHub {
      #     owner = "jethrokuan";
      #     repo = "z";
      #     rev = "e0e1b9dfdba362f8ab1ae8c1afc7ccf62b89f7eb";
      #     sha256 = "0dbnir6jbwjpjalz14snzd3cgdysgcs3raznsijd6savad3qhijc";
      #   };
      # }
    ];
    shellAliases = {
        ls = "lsd";
        l = "ls -l";
        ll = "ls -a";
        lla = "ls -la";
        lt = "ls --tree";
        cat = "bat --paging=never -p";
        cd = "z";
        rm = "trash";
        ps = "procs";
        du = "dust";
        top = "btop";
        diff = "delta";
        network = "bandwhich";
        npm_legacy = "command npm";
        npm = "pnpm";
        npx_legacy = "command npx";
        npx = "pnpx";
        http = "xh";
      };
    shellInit = ''
      zoxide init fish | source
    '';
  };

  programs.bash = {
    initExtra = ''
      if [[ $(${pkgs.procps}/bin/ps --no-header --pid=$PPID --format=comm) != "fish" && -z ''${BASH_EXECUTION_STRING} ]]
      then
        shopt -q login_shell && LOGIN_OPTION='--login' || LOGIN_OPTION=""
        exec ${pkgs.fish}/bin/fish $LOGIN_OPTION
      fi
    '';
  };
}
