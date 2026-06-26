{
  description = "Declarative systems for darwin, NixOS, and WSL hosts";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-26.05";
    nix-darwin.url = "github:nix-darwin/nix-darwin/nix-darwin-26.05";
    nix-darwin.inputs.nixpkgs.follows = "nixpkgs";
    nixpkgs-unstable.url = "github:nixos/nixpkgs/nixos-unstable";
    nixos-wsl.url = "github:nix-community/NixOS-WSL";
    nixos-wsl.inputs.nixpkgs.follows = "nixpkgs";
    nixvim.url = "github:nix-community/nixvim/nixos-26.05";
    nixvim.inputs.nixpkgs.follows = "nixpkgs";
  };

  outputs = inputs@{ nixpkgs, nix-darwin, nixos-wsl, nixvim, nixpkgs-unstable, ... }:
    let
      mkSpecialArgs = system: {
        inherit inputs;
        pkgsUnstable = import nixpkgs-unstable {
          inherit system;
        };
      };

      mkDarwin = { name, system ? "aarch64-darwin", modules ? [ ] }:
        nix-darwin.lib.darwinSystem {
          inherit system;
          modules =
            modules
            ++ [
              ./modules/packages
              ../hosts/darwin/${name}
              ({ self, ... }: {
                system.configurationRevision = self.rev or self.dirtyRev or null;
              })
            ];
          specialArgs = mkSpecialArgs system;
        };

      mkNixos = { name, system ? "x86_64-linux", modules ? [ ] }:
        nixpkgs.lib.nixosSystem {
          inherit system;
          modules = modules ++ [
            ./modules/packages
            ../hosts/nixos/${name}
          ];
          specialArgs = mkSpecialArgs system;
        };

      mkWsl = { name, system ? "x86_64-linux", modules ? [ ] }:
        nixpkgs.lib.nixosSystem {
          inherit system;
          modules = modules ++ [
            ./modules/packages
            ../hosts/wsl/${name}
          ];
          specialArgs = mkSpecialArgs system;
        };
    in {
      darwinConfigurations.macbook = mkDarwin { name = "macbook"; };

      nixosConfigurations.lenovo-ideapadslim3 = mkNixos {
        name = "lenovo-ideapadslim3";
        modules = [
          nixvim.nixosModules.default
        ];
      };

      nixosConfigurations.wsl = mkWsl { name = "default"; };
    };
}
