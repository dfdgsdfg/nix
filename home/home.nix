{ config, pkgs, lib, ... }:
let
  pnpmHome =
    if pkgs.stdenv.isDarwin then
      "${config.home.homeDirectory}/Library/pnpm"
    else
      "${config.home.homeDirectory}/.local/share/pnpm";

  commonShellAliases = {
    ls = "lsd";
    l = "ls -l";
    la = "ls -a";
    lla = "ls -la";
    lt = "ls --tree";
    cat = "bat --paging=never -p";
    rm = "trash";
    ps = "procs";
    du = "dust";
    top = "btm";
    diff = "delta";
    network = "bandwhich";
    npm_legacy = "command npm";
    npm = "pnpm";
    npx_legacy = "command npx";
    npx = "pnpx";
    http = "xh";
  };

  fishShellAliases = commonShellAliases // {
    cd = "z";
  };

  globalGitIgnores = [
    ".DS_Store"
    ".AppleDouble"
    ".LSOverride"
    "Icon"
    "._*"
    ".DocumentRevisions-V100"
    ".fseventsd"
    ".Spotlight-V100"
    ".TemporaryItems"
    ".Trashes"
    ".VolumeIcon.icns"
    ".AppleDB"
    ".AppleDesktop"
    "Network Trash Folder"
    "Temporary Items"
    ".apdisk"
    "Thumbs.db"
    "ehthumbs.db"
    "Desktop.ini"
    "$RECYCLE.BIN/"
    "*.cab"
    "*.msi"
    "*.msm"
    "*.msp"
    "*.lnk"
    "*~"
    ".directory"
    ".Trash-*"
    "[._]*.s[a-w][a-z]"
    "[._]s[a-w][a-z]"
    "*.un~"
    "Session.vim"
    ".netrwhist"
    "**/.claude/settings.local.json"
  ];
in
{
  imports = [
    ../modules/nvim
    ../modules/ssh
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
    secrets."ssh/github/id_ed25519" = {
      format = "yaml";
      sopsFile = ../secrets/ssh.yaml;
      key = "ssh/github/id_ed25519";
    };
    secrets."ssh/github/id_ed25519.pub" = {
      format = "yaml";
      sopsFile = ../secrets/ssh.yaml;
      key = "ssh/github/id_ed25519_pub";
    };
  };

  modules.nvim.enable = true;
  modules.ssh = {
    enable = true;
    identities.github = {
      secret = "ssh/github/id_ed25519";
      target = ".ssh/github_ed25519";
      publicKeySecret = "ssh/github/id_ed25519.pub";
    };
    settings = {
      "github.com" = {
        User = "git";
        HostName = "github.com";
        IdentityFile = "~/.ssh/github_ed25519";
        IdentitiesOnly = true;
        Compression = true;
      };
      "*" = {
        AddKeysToAgent = "yes";
        Compression = true;
        VisualHostKey = false;
      };
    };
  };

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
    ignores = globalGitIgnores;
    settings = {
      user = {
        name = "sg";
        email = "dfdgsdfg@gmail.com";
      };
      pager = {
        diff = "delta";
        log = "delta";
        reflog = "delta";
        show = "delta";
      };
      interactive.diffFilter = "delta --color-only --features=interactive";
      delta.features = "decorations";
      "delta \"interactive\"".keep-plus-minus-markers = false;
      "delta \"decorations\"" = {
        commit-decoration-style = "blue ol";
        commit-style = "raw";
        file-style = "omit";
        hunk-header-decoration-style = "blue box";
        hunk-header-file-style = "red";
        hunk-header-line-number-style = "#067a00";
        hunk-header-style = "file line-number syntax";
      };
      alias.root = "rev-parse --show-toplevel";
      fetch.pruneTags = true;
      pull.rebase = false;
      push.autoSetupRemote = true;
    };
  };

  programs.delta = {
    enable = true;
    enableGitIntegration = false;
  };

  programs.zsh = {
    enable = true;
    shellAliases = commonShellAliases;
    oh-my-zsh = {
      enable = true;
      theme = "robbyrussell";
      plugins = [ "git" "fzf" ];
    };
  };

  programs.fish = {
    enable = true;
    shellAliases = fishShellAliases;
    shellInit = ''
      set -gx fisher_home ~/.local/share/fisherman
      set -gx fisher_config ~/.config/fisherman

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
    enableZshIntegration = true;
  };

  programs.atuin = {
    enable = true;
    enableFishIntegration = true;
    enableZshIntegration = true;
  };

  programs.zoxide = {
    enable = true;
    enableFishIntegration = true;
    enableZshIntegration = true;
  };

  programs.navi = {
    enable = true;
    enableFishIntegration = true;
    enableZshIntegration = true;
  };

  programs.mise = {
    enable = true;
    enableFishIntegration = true;
    enableZshIntegration = true;
    globalConfig.tools = {
      node = "lts";
      python = "miniconda3-latest";
      deno = "latest";
      java = "zulu-25";
      ruby = "latest";
      go = "latest";
      bun = "latest";
      erlang = "latest";
      zig = "latest";
      uv = "latest";
      fnox = "latest";
    };
  };

  programs.direnv = {
    enable = true;
    enableFishIntegration = true;
    enableZshIntegration = true;
    nix-direnv.enable = true;
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
      NODE_OPTIONS = "--max-old-space-size=8192";
      COREPACK_HOME = "${config.home.homeDirectory}/.cache/corepack";
      PNPM_HOME = pnpmHome;
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
      "${config.home.homeDirectory}/.antigravity/antigravity/bin"
      "${config.home.homeDirectory}/.elan/bin"
      "${config.home.homeDirectory}/opt/tlpas/lib"
      "${pnpmHome}/bin"
      pnpmHome
    ]
    ++ lib.optionals pkgs.stdenv.isDarwin [
      "${config.home.homeDirectory}/Library/Android/sdk/tools"
      "${config.home.homeDirectory}/Library/Android/sdk/tools/bin"
      "${config.home.homeDirectory}/Library/Android/sdk/platform-tools"
      "/Applications/Visual Studio Code.app/Contents/Resources/app/bin"
    ]
  );

  home.file.".default-python-packages".text = ''
    pynvim
  '';

  home.file.".default-gems".text = ''
    bundler
    cocoapods
    fastlane
    neovim
  '';

  xdg.configFile."direnv/direnvrc".text = ''
    # Uncomment the following line to make direnv silent by default.
    # export DIRENV_LOG_FORMAT=""
  '';
}
