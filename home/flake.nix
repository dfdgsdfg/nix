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
    nix-claude-code = {
      url = "github:ryoppippi/nix-claude-code";
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

  outputs = inputs@{ nixpkgs, home-manager, nix-claude-code, sops-nix, nixpkgs-unstable, ... }:
    let
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

      mkLinuxHostHome = { host, username ? "dididi", homeDirectory ? "/home/${username}" }:
        mkHome {
          system = "x86_64-linux";
          inherit username homeDirectory;
          modules = [
            ./hosts/nixos/${host}
          ];
          overlays = [
            nix-claude-code.overlays.default
          ];
        };

      mkDarwinHostHome = { host, username ? "dididi", homeDirectory ? "/Users/${username}" }:
        mkHome {
          system = "aarch64-darwin";
          inherit username homeDirectory;
          modules = [
            ./home.nix
            ./hosts/darwin/${host}
          ];
        };

      mkWslHostHome = { host ? "default", username ? "dididi", homeDirectory ? "/home/${username}" }:
        mkHome {
          system = "x86_64-linux";
          inherit username homeDirectory;
          modules = [
            ./home.nix
            ./hosts/wsl/${host}
          ];
        };

      homeConfigurations = {
        "dididi@macbook" = mkDarwinHostHome {
          host = "macbook";
        };

        "dididi@desktop" = mkHome {
          system = "x86_64-linux";
          username = "dididi";
          homeDirectory = "/home/dididi";
        };

        "dididi@lenovo-ideapadslim3" = mkLinuxHostHome {
          host = "lenovo-ideapadslim3";
        };

        "dididi@wsl" = mkWslHostHome { };
      };
    in {
      inherit homeConfigurations;

      packages = {
        aarch64-darwin.default =
          homeConfigurations."dididi@macbook".activationPackage;

        x86_64-linux.desktop =
          homeConfigurations."dididi@desktop".activationPackage;

        x86_64-linux.lenovo-ideapadslim3 =
          homeConfigurations."dididi@lenovo-ideapadslim3".activationPackage;

        x86_64-linux.wsl =
          homeConfigurations."dididi@wsl".activationPackage;
      };
    };
}
