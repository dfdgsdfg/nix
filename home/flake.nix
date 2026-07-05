{
  description = "Home Manager configurations for dididi across hosts";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";
    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    nixpkgs-unstable = {
      url = "github:nixos/nixpkgs/nixos-unstable";
    };
    zen-browser = {
      url = "github:0xc000022070/zen-browser-flake";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    claude-code-nix = {
      url = "github:sadjow/claude-code-nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    codex-cli-nix = {
      url = "github:sadjow/codex-cli-nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    seance = {
      url = "git+https://github.com/dfdgsdfg/seance.git?ref=codex/fix-ime-composition-key-routing&submodules=1";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    sops-nix = {
      url = "github:Mic92/sops-nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = inputs@{ nixpkgs, home-manager, sops-nix, nixpkgs-unstable, ... }:
    let
      lib = nixpkgs.lib;
      hosts = import ../hosts { inherit inputs; };
      systems = lib.unique (map (host: host.system) (lib.attrValues hosts));

      forAllSystems = f:
        lib.genAttrs systems (system:
          f (import nixpkgs {
            inherit system;
            config.allowUnfree = true;
          })
        );

      mkHome = { system, username, homeDirectory, modules ? [ ./home.nix ], overlays ? [ ] }:
        let
          pkgsUnstable = import nixpkgs-unstable {
            inherit system;
            config.allowUnfree = true;
          };
          pkgs = import nixpkgs {
            inherit system overlays;
            config.allowUnfree = true;
          };
        in home-manager.lib.homeManagerConfiguration {
          inherit pkgs;
          modules = [
            inputs.sops-nix.homeManagerModules.sops
          ] ++ modules ++ [
            {
              home.username = username;
              home.homeDirectory = homeDirectory;
            }
          ];
          extraSpecialArgs = {
            inherit inputs pkgsUnstable;
          };
        };

      mkHostHome = host:
        mkHome {
          inherit (host) system username homeDirectory;
          modules = host.homeModules;
        };

      homeConfigurations =
        lib.mapAttrs'
          (name: host: lib.nameValuePair "${host.username}@${name}" (mkHostHome host))
          hosts;

      mkActivationPackage = packages: name:
        let
          host = hosts.${name};
          packageName = host.homePackageName or name;
          configName = "${host.username}@${name}";
        in
        packages
        // {
          ${host.system} = (packages.${host.system} or { }) // {
            ${packageName} = homeConfigurations.${configName}.activationPackage;
          };
        };
    in {
      inherit homeConfigurations;

      packages = lib.foldl' mkActivationPackage { } (lib.attrNames hosts);

      devShells = forAllSystems (pkgs: {
        build = pkgs.mkShell {
          packages = with pkgs; [
            autoconf
            automake
            bzip2
            clang
            cmake
            gcc
            gnumake
            libffi
            libtool
            libyaml
            ncurses
            openssl
            pkg-config
            readline
            sqlite
            xz
            zlib
          ];
        };
      });
    };
}
