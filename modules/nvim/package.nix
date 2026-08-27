{
  includeFlutter ? false,
  inputs,
  pkgs,
}:
let
  flutterSpec =
    if includeFlutter then
      ''
        {
          dir = "${pkgs.vimPlugins.flutter-tools-nvim}",
          name = "flutter-tools.nvim",
          dependencies = {
            { dir = "${pkgs.vimPlugins.plenary-nvim}", name = "plenary.nvim" },
          },
        },
      ''
    else
      "";
  lazyPath = "${pkgs.vimPlugins.lazy-nvim}";
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
    vim.opt.rtp:prepend("${lazyPath}")
    local plugin_tasks = require("lazy.manage.task.plugin")
    local skip_docs = plugin_tasks.docs.skip
    plugin_tasks.docs.skip = function(plugin)
      return vim.startswith(plugin.dir, "/nix/store/") or skip_docs(plugin)
    end

    require("lazy").setup({
      spec = {
        {
          dir = "${pkgs.vimPlugins.LazyVim}",
          name = "LazyVim",
        },
        { import = "lazyvim.plugins" },
        { import = "lazyvim.plugins.extras.editor.telescope" },
        { import = "lazyvim.plugins.extras.lang.typescript" },
        { import = "lazyvim.plugins.extras.util.project" },
        ${flutterSpec}
      },
      defaults = {
        lazy = false,
        version = false,
      },
      rocks = {
        hererocks = false,
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

      specs.plugins =
        (with pkgs.vimPlugins; [
          lazy-nvim
          LazyVim
        ])
        ++ pkgs.lib.optionals includeFlutter (
          with pkgs.vimPlugins;
          [
            flutter-tools-nvim
            plenary-nvim
          ]
        );
    }
  );
in
{
  package = wrapper.config.wrap { inherit pkgs; };
  runtimePackages = with pkgs; [
    fd
    cmake
    gcc
    lua5_1
    lua51Packages.luarocks
    gnumake
    lazygit
    lua-language-server
    nil
    ripgrep
    stylua
    tree-sitter
  ];
}
