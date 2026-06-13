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
    sops-nix = {
      url = "github:Mic92/sops-nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = inputs@{ nixpkgs, home-manager, nix-claude-code, sops-nix, nixpkgs-unstable, ... }:
    let
      mkHome = { system, username, homeDirectory }:
        let
          pkgsUnstable = import nixpkgs-unstable {
            inherit system;
            config.allowUnfree = true;
          };
        in home-manager.lib.homeManagerConfiguration {
          pkgs = nixpkgs.legacyPackages.${system};
          modules = [
            inputs.sops-nix.homeManagerModules.sops
            ./home.nix
            {
              home.username = username;
              home.homeDirectory = homeDirectory;
            }
          ];
          extraSpecialArgs = {
            inherit inputs pkgsUnstable;
          };
        };

      mkLenovoHome =
        let
          system = "x86_64-linux";
          pkgs = import nixpkgs {
            inherit system;
            config.allowUnfree = true;
            overlays = [
              nix-claude-code.overlays.default
            ];
          };
        in home-manager.lib.homeManagerConfiguration {
          inherit pkgs;
          modules = [
            ./hosts/lenovo-ideapadslim3/home.nix
          ];
          extraSpecialArgs = {
            inherit inputs;
          };
        };

      homeConfigurations = {
        "dididi@macbook" = mkHome {
          system = "aarch64-darwin";
          username = "dididi";
          homeDirectory = "/Users/dididi";
        };

        "dididi@desktop" = mkHome {
          system = "x86_64-linux";
          username = "dididi";
          homeDirectory = "/home/dididi";
        };

        "dididi@lenovo-ideapadslim3" = mkLenovoHome;

        "dididi@wsl" = mkHome {
          system = "x86_64-linux";
          username = "dididi";
          homeDirectory = "/home/dididi";
        };
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
