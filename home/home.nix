{
  config,
  pkgs,
  lib,
  ...
}:
let
  isDarwin = pkgs.stdenv.hostPlatform.isDarwin;
  brewPrefix = if pkgs.stdenv.hostPlatform.isAarch64 then "/opt/homebrew" else "/usr/local";
  brewMise = "${brewPrefix}/bin/mise";
  pathOrder = import ./path-order.nix;
  pnpmHome =
    if isDarwin then
      "${config.home.homeDirectory}/Library/pnpm"
    else
      "${config.home.homeDirectory}/.local/share/pnpm";

  ccacheWrappers = pkgs.runCommand "ccache-wrappers" { } ''
    mkdir -p "$out/bin"
    for compiler in cc c++ gcc g++ clang clang++; do
      ln -s ${lib.getExe pkgs.ccache} "$out/bin/$compiler"
    done
  '';

  homeSecrets = ../secrets/home.yaml;

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
    "Icon\r"
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
    ./modules/claude
    ./modules/codex
    ./modules/omp
    ./modules/pi
    ./modules/nvim
    ./modules/ssh
  ];

  nixpkgs.config.allowUnfree = true;

  sops = {
    age.keyFile = lib.mkDefault "${config.home.homeDirectory}/.config/sops/age/keys.txt";
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
    secrets."git/config-user" = {
      format = "yaml";
      sopsFile = homeSecrets;
      key = "git/config_user";
      path = "${config.xdg.configHome}/git/config-user";
      mode = "0600";
    };
    secrets."git/config-user-work" = {
      format = "yaml";
      sopsFile = homeSecrets;
      key = "git/config_user_work";
      path = "${config.xdg.configHome}/git/config-user-work";
      mode = "0600";
    };
    secrets."git/config-user-work-us" = {
      format = "yaml";
      sopsFile = homeSecrets;
      key = "git/config_user_work_us";
      path = "${config.xdg.configHome}/git/config-user-work-us";
      mode = "0600";
    };
    secrets."fish/credential" = {
      format = "yaml";
      sopsFile = homeSecrets;
      key = "fish/credential";
      path = "${config.xdg.configHome}/fish/credential.fish";
      mode = "0600";
    };
  };

  modules.nvim.enable = true;
  modules.claude.enable = true;
  modules.codex.enable = true;
  modules.omp.enable = true;
  modules.pi.enable = true;
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

  programs.home-manager.enable = true;

  # Home Manager's manpage generator currently creates options.json with
  # builtins.derivation and drops the source store context.
  manual.manpages.enable = false;

  programs.helix = {
    enable = true;
    defaultEditor = true;
  };

  programs.git = {
    enable = true;
    ignores = globalGitIgnores;
    settings = {
      include.path = "${config.xdg.configHome}/git/config-user";
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
      "credential \"https://github.com\"".helper = [
        ""
        "!${pkgs.gh}/bin/gh auth git-credential"
      ];
      "credential \"https://gist.github.com\"".helper = [
        ""
        "!${pkgs.gh}/bin/gh auth git-credential"
      ];
    };
  };

  programs.delta = {
    enable = true;
    enableGitIntegration = false;
  };

  programs.zsh = {
    enable = true;
    shellAliases = commonShellAliases;
    initContent = lib.mkIf isDarwin ''
      if [[ -x ${brewMise} ]]; then
        eval "$(${brewMise} activate zsh)"
      fi
    '';
    oh-my-zsh = {
      enable = true;
      theme = "robbyrussell";
      plugins = [
        "git"
        "fzf"
      ];
    };
  };

  programs.fish = {
    enable = true;
    plugins = [
      {
        name = "grc";
        src = pkgs.fishPlugins.grc.src;
      }
    ];
    shellAliases = fishShellAliases;
    interactiveShellInit = lib.mkIf isDarwin ''
      if test -x ${brewMise}
        ${brewMise} activate fish | source
      end
    '';
    shellInit = ''
      set -gx fisher_home ~/.local/share/fisherman
      set -gx fisher_config ~/.config/fisherman

      test -e ~/.iterm2_shell_integration.fish; and source ~/.iterm2_shell_integration.fish

      if test -f "${config.xdg.configHome}/fish/credential.fish"
        source "${config.xdg.configHome}/fish/credential.fish"
      end
    '';
  };

  programs.bash = {
    enable = true;
    shellAliases = commonShellAliases;
    initExtra = lib.mkIf isDarwin ''
      if [[ -x ${brewMise} ]]; then
        eval "$(${brewMise} activate bash)"
      fi
    '';
  };
  programs.starship = {
    enable = true;
    enableBashIntegration = true;
    enableFishIntegration = true;
    enableZshIntegration = true;
  };

  programs.atuin = {
    enable = true;
    enableBashIntegration = true;
    enableFishIntegration = true;
    enableZshIntegration = true;
  };

  programs.zoxide = {
    enable = true;
    enableBashIntegration = true;
    enableFishIntegration = true;
    enableZshIntegration = true;
  };

  programs.navi = {
    enable = true;
    enableBashIntegration = true;
    enableFishIntegration = true;
    enableZshIntegration = true;
  };

  programs.mise = {
    enable = true;
    package = if isDarwin then null else pkgs.mise;
    enableBashIntegration = !isDarwin;
    enableFishIntegration = !isDarwin;
    enableNushellIntegration = !isDarwin;
    enableZshIntegration = !isDarwin;
    globalConfig = {
      settings.all_compile = false;
      tools = {
        node = "lts";
        pnpm = "latest";
        python = "miniconda3-latest";
        deno = "latest";
        java = "temurin-25";
        ruby = "latest";
        go = "latest";
        bun = "latest";
        erlang = "latest";
        zig = "latest";
        uv = "latest";
      };
    };
  };

  # Keep the legacy asdf path working for tools and editor integrations that
  # still look for mise-managed runtimes under ~/.asdf.
  home.file.".asdf" = {
    source = config.lib.file.mkOutOfStoreSymlink (
      "${config.home.homeDirectory}/.local/share/mise"
    );
    force = true;
  };

  programs.direnv = {
    enable = true;
    enableBashIntegration = true;
    enableFishIntegration = true;
    enableZshIntegration = true;
    nix-direnv.enable = true;
  };

  home.stateVersion = lib.mkDefault "24.11";

  home.sessionVariables = {
    LANG = "ko_KR.UTF-8";
    EDITOR = "hx";
    VISUAL = "hx";
    GIT_EDITOR = "hx";
    GO111MODULE = "on";
    CLOUDSDK_PYTHON_SITEPACKAGES = "1";
    USE_GKE_GCLOUD_AUTH_PLUGIN = "True";
    NO_PROXY = "localhost,127.0.0.1";
    NODE_OPTIONS = "--max-old-space-size=8192";
    COREPACK_HOME = "${config.home.homeDirectory}/.cache/corepack";
    PNPM_HOME = pnpmHome;
    SOPS_AGE_KEY_FILE = "${config.home.homeDirectory}/.config/sops/age/keys.txt";
    CCACHE_SLOPPINESS = "clang_index_store,file_stat_matches,include_file_ctime,include_file_mtime,ivfsoverlay,pch_defines,modules,system_headers,time_macros";
    CCACHE_FILECLONE = "true";
    CCACHE_DEPEND = "true";
    CCACHE_INODECACHE = "true";
  }
  // lib.optionalAttrs pkgs.stdenv.hostPlatform.isDarwin {
    ANDROID_HOME = "${config.home.homeDirectory}/Library/Android/sdk";
  };

  # Command precedence: user bins -> mise -> user packages -> user opt/tools
  # -> SDK/apps -> compiler wrappers -> Homebrew (Darwin) -> Nix -> OS.
  home.sessionPath = lib.mkMerge [
    (lib.mkOrder pathOrder.userBin [
      "${config.home.homeDirectory}/bin"
      "${config.home.homeDirectory}/.local/bin"
    ])
    (lib.mkOrder pathOrder.mise [
      "${config.home.homeDirectory}/.local/share/mise/shims"
    ])
    (lib.mkOrder pathOrder.userPackage [
      "${pnpmHome}/bin"
      pnpmHome
      "${config.home.homeDirectory}/.cargo/bin"
      "${config.home.homeDirectory}/.pub-cache/bin"
    ])
    (lib.mkOrder pathOrder.userOpt [
      "${config.home.homeDirectory}/opt/bin"
      "${config.home.homeDirectory}/opt/bin/depot_tools"
      "${config.home.homeDirectory}/.maestro/bin"
      "${config.home.homeDirectory}/.antigravity/antigravity/bin"
      "${config.home.homeDirectory}/.elan/bin"
      "${config.home.homeDirectory}/opt/tlpas/lib"
    ])
    (lib.mkOrder pathOrder.sdk (lib.optionals isDarwin [
      "${config.home.homeDirectory}/Library/Android/sdk/tools"
      "${config.home.homeDirectory}/Library/Android/sdk/tools/bin"
      "${config.home.homeDirectory}/Library/Android/sdk/platform-tools"
      "/Applications/Visual Studio Code.app/Contents/Resources/app/bin"
    ]))
    (lib.mkOrder pathOrder.compilerWrapper [
      "${ccacheWrappers}/bin"
    ])
  ];

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
