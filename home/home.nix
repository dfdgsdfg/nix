{ config, pkgs, lib, ... }:
let
  secretPath = config.sops.secrets."example-token".path;
in
{
  imports = [
    ../modules/nvim
    ../packages
  ];

  nixpkgs.config.allowUnfree = true;

  sops = {
    defaultSopsFile = ../secrets/example.yaml;
    age.keyFile = lib.mkDefault "${config.home.homeDirectory}/.config/sops/age/keys.txt";
    secrets."example-token" = {
      format = "yaml";
      key = "example.token";
    };
  };

  home.file.".config/example/token" = {
    source = secretPath;
    recursive = false;
  };

  modules.nvim.enable = true;

  modules.packages = {
    core.enable = true;
    dev.enable = true;
    network.enable = true;
    ops.enable = true;
    mobile.enable = pkgs.stdenv.isDarwin;
    gui.enable = pkgs.stdenv.isDarwin;
  };

  programs.home-manager.enable = true;

  programs.git = {
    enable = true;
    userName = "dididi";
    userEmail = "dididi@example.com";
  };

  programs.zsh = {
    enable = true;
    oh-my-zsh = {
      enable = true;
      theme = "robbyrussell";
      plugins = [ "git" "fzf" ];
    };
  };

  programs.fish = {
    enable = true;
    shellAliases = {
      ls = "lsd";
      l = "ls -l";
      la = "ls -a";
      lla = "ls -la";
      lt = "ls --tree";
      cat = "bat --paging=never";
      cd = "z";
      rm = "trash";
      ps = "procs";
      du = "dust";
      top = "btm";
      diff = "delta";
      network = "bandwhich";
    };
    shellInit = ''
      set -gx fisher_home ~/.local/share/fisherman
      set -gx fisher_config ~/.config/fisherman

      if type -q mise
        if test "$VSCODE_RESOLVING_ENVIRONMENT" = 1
          mise activate fish --shims | source
        else if status is-interactive
          mise activate fish | source
        else
          mise activate fish --shims | source
        end
      end

      if test -f "$HOME/.cargo/env.fish"
        source "$HOME/.cargo/env.fish"
      end

      test -e ~/.iterm2_shell_integration.fish; and source ~/.iterm2_shell_integration.fish
      test -f ~/.config/fish/credential.fish; and source ~/.config/fish/credential.fish

      if status is-interactive
        if type -q navi
          navi widget fish | source
        end
      end

      if type -q ccache
        set -gx CCACHE_SLOPPINESS clang_index_store,file_stat_matches,include_file_ctime,include_file_mtime,ivfsoverlay,pch_defines,modules,system_headers,time_macros
        set -gx CCACHE_FILECLONE true
        set -gx CCACHE_DEPEND true
        set -gx CCACHE_INODECACHE true
      end
    '';
  };

  programs.starship = {
    enable = true;
    enableFishIntegration = true;
  };

  programs.atuin = {
    enable = true;
    enableFishIntegration = true;
  };

  programs.zoxide = {
    enable = true;
    enableFishIntegration = true;
  };

  programs.navi = {
    enable = true;
    enableFishIntegration = true;
  };

  home.stateVersion = lib.mkDefault "24.11";

  home.sessionVariables =
    {
      LANG = "ko_KR.UTF-8";
      EDITOR = "nvim";
      GO111MODULE = "on";
      CLOUDSDK_PYTHON_SITEPACKAGES = "1";
      USE_GKE_GCLOUD_AUTH_PLUGIN = "True";
      NO_PROXY = "localhost,127.0.0.1";
      NODE_OPTIONS = "--max-old-space-size=8096";
    }
    // lib.optionalAttrs pkgs.stdenv.isDarwin {
      ANDROID_HOME = "${config.home.homeDirectory}/Library/Android/sdk";
    };

  home.sessionPath = lib.mkAfter (
    [
      "${config.home.homeDirectory}/bin"
      "${config.home.homeDirectory}/.local/bin"
      "${config.home.homeDirectory}/.pub-cache/bin"
      "${config.home.homeDirectory}/opt/bin"
      "${config.home.homeDirectory}/opt/bin/depot_tools"
      "${config.home.homeDirectory}/.maestro/bin"
    ]
    ++ lib.optionals pkgs.stdenv.isDarwin [
      "${config.home.homeDirectory}/Library/Android/sdk/tools"
      "${config.home.homeDirectory}/Library/Android/sdk/tools/bin"
      "${config.home.homeDirectory}/Library/Android/sdk/platform-tools"
      "/Applications/Visual Studio Code.app/Contents/Resources/app/bin"
    ]
  );
}
