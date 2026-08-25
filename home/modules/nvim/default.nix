{ config, lib, pkgs, ... }:
let
  cfg = config.modules.nvim;
  lazyPath = "${pkgs.vimPlugins.lazy-nvim}/share/vim-plugins/lazy-nvim";
  lazyConfig = ''
    local lazypath = "${lazyPath}"
    vim.opt.rtp:prepend(lazypath)

    require("lazy").setup({
      spec = {
        { "LazyVim/LazyVim", import = "lazyvim.plugins" },
        { import = "lazyvim.plugins.extras.editor.telescope" },
        { import = "lazyvim.plugins.extras.lang.typescript" },
        { import = "lazyvim.plugins.extras.util.project" },
        { "akinsho/flutter-tools.nvim", dependencies = "nvim-lua/plenary.nvim" },
      },
      defaults = {
        lazy = false,
        version = nil,
      },
      install = {
        colorscheme = { "catppuccin", "tokyonight" },
      },
      checker = {
        enabled = false,
      },
      performance = {
        rtp = {
          disabled_plugins = {
            "gzip",
            "tarPlugin",
            "tohtml",
            "tutor",
            "zipPlugin",
          },
        },
      },
    })
  '';
in
{
  options.modules.nvim.enable =
    lib.mkEnableOption "LazyVim-flavoured Neovim configuration";

  config = lib.mkIf cfg.enable {
    home.sessionVariables.EDITOR = lib.mkDefault "nvim";

    home.packages = lib.mkAfter (with pkgs; [
      fd
      lazygit
      lua-language-server
      ripgrep
      stylua
      tree-sitter
    ]);

    programs.neovim = {
      enable = true;
      defaultEditor = true;
      viAlias = true;
      vimAlias = true;
      withNodeJs = true;
      withPython3 = true;
      withRuby = true;
      extraPackages = with pkgs; [
        nil
        tree-sitter
      ];
    };
    # Older generations managed lua as one symlink. Remove only that Nix-store
    # link before Home Manager creates the new per-file directory hierarchy.
    home.activation.migrateNvimLua = lib.hm.dag.entryBefore [ "linkGeneration" ] ''
      lua_path="$HOME/.config/nvim/lua"
      if [ -L "$lua_path" ]; then
        target="$(${pkgs.coreutils}/bin/readlink "$lua_path")"
        case "$target" in
          /nix/store/*)
            run rm "$lua_path"
            ;;
        esac
      fi
    '';


    xdg.configFile."nvim/init.lua".text = ''
      require("config.lazy")
      require("config.options")
      require("config.keymaps")
    '';

    xdg.configFile."nvim/lua/config/lazy.lua".text = lazyConfig;

    xdg.configFile."nvim/lua/config/options.lua".text = ''
      vim.g.mapleader = " "
      vim.g.maplocalleader = ","
      vim.env.PATH = vim.env.HOME .. "/.local/share/mise/shims:" .. vim.env.PATH

      local opt = vim.opt

      opt.termguicolors = true
      opt.number = true
      opt.relativenumber = true
      opt.signcolumn = "yes"
      opt.clipboard = "unnamedplus"
      opt.timeoutlen = 400
      opt.updatetime = 200
    '';

    xdg.configFile."nvim/lua/config/keymaps.lua".text = ''
      local map = vim.keymap.set

      map("n", "<leader>ff", "<cmd>Telescope find_files<cr>", { desc = "Find files" })
      map("n", "<leader>fg", "<cmd>Telescope live_grep<cr>", { desc = "Live grep" })
      map("n", "<leader>fb", "<cmd>Telescope buffers<cr>", { desc = "Find buffers" })
      map("n", "<leader>fh", "<cmd>Telescope help_tags<cr>", { desc = "Find help" })
    '';
  };
}
