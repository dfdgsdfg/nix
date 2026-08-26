{
  config,
  inputs,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.modules.nvim;
  configDirectory = pkgs.runCommand "lazyvim-config" { } ''
    mkdir -p "$out/lua/config"
    cat > "$out/init.lua" <<'EOF'
    require("config.options")
    require("config.lazy")
    EOF
    cat > "$out/lua/config/options.lua" <<'EOF'
    vim.g.mapleader = " "
    vim.g.maplocalleader = ","
    vim.env.PATH = vim.env.HOME .. "/.local/share/mise/shims:" .. vim.env.PATH
    EOF
    cat > "$out/lua/config/lazy.lua" <<'EOF'
    require("lazy").setup({
      spec = {
        {
          dir = "${pkgs.vimPlugins.LazyVim}",
          name = "LazyVim",
          import = "lazyvim.plugins",
        },
        { import = "lazyvim.plugins.extras.editor.telescope" },
        { import = "lazyvim.plugins.extras.lang.typescript" },
        { import = "lazyvim.plugins.extras.util.project" },
        {
          dir = "${pkgs.vimPlugins.flutter-tools-nvim}",
          name = "flutter-tools.nvim",
          dependencies = {
            { dir = "${pkgs.vimPlugins.plenary-nvim}", name = "plenary.nvim" },
          },
        },
      },
      defaults = {
        lazy = false,
        version = false,
      },
      checker = { enabled = false },
      performance = {
        rtp = {
          reset = false,
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
    EOF
  '';
  wrapper = inputs.nix-wrapper-modules.lib.evalModule (
    { wlib, pkgs, ... }:
    {
      imports = [ wlib.wrapperModules.neovim ];

      settings = {
        config_directory = configDirectory;
        aliases = [
          "vi"
          "vim"
        ];
      };

      specs.plugins = with pkgs.vimPlugins; [
        lazy-nvim
        LazyVim
        flutter-tools-nvim
        plenary-nvim
      ];
    }
  );
in
{
  options.modules.nvim.enable = lib.mkEnableOption "Nix-wrapped LazyVim configuration";

  config = lib.mkIf cfg.enable {
    home.packages =
      (with pkgs; [
        fd
        lazygit
        lua-language-server
        nil
        ripgrep
        stylua
        tree-sitter
      ])
      ++ [ (wrapper.config.wrap { inherit pkgs; }) ];
  };
}
