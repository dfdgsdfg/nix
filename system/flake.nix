{
  description = "Declarative systems for darwin, NixOS, and WSL hosts";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-25.05";
    nix-darwin.url = "github:nix-darwin/nix-darwin/nix-darwin-25.05";
    nix-darwin.inputs.nixpkgs.follows = "nixpkgs";
    nixpkgs-unstable.url = "github:nixos/nixpkgs/nixos-unstable";
    home-manager.url = "github:nix-community/home-manager/release-25.05";
    home-manager.inputs.nixpkgs.follows = "nixpkgs";
    nixpkgs-26_05.url = "github:nixos/nixpkgs/nixos-26.05";
    nixos-wsl.url = "github:nix-community/NixOS-WSL";
    nixos-wsl.inputs.nixpkgs.follows = "nixpkgs";
    nixvim.url = "github:nix-community/nixvim/nixos-26.05";
    nixvim.inputs.nixpkgs.follows = "nixpkgs-26_05";
    sops-nix.url = "github:Mic92/sops-nix";
    sops-nix.inputs.nixpkgs.follows = "nixpkgs";
  };

  outputs = inputs@{ nixpkgs, nix-darwin, home-manager, nixpkgs-26_05, nixos-wsl, nixvim, sops-nix, nixpkgs-unstable, ... }:
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
              ../hosts/darwin/${name}.nix
              ({ self, ... }: {
                system.configurationRevision = self.rev or self.dirtyRev or null;
              })
            ];
          specialArgs = mkSpecialArgs system;
        };

      mkNixos = { name, system ? "x86_64-linux", nixpkgsInput ? nixpkgs, modules ? [ ] }:
        nixpkgsInput.lib.nixosSystem {
          inherit system;
          modules = modules ++ [ ../hosts/nixos/${name}.nix ];
          specialArgs = mkSpecialArgs system;
        };

      mkWsl = { name, system ? "x86_64-linux", modules ? [ ] }:
        nixos-wsl.lib.nixosSystem {
          inherit system;
          modules = modules ++ [ ../hosts/wsl/${name}.nix ];
          specialArgs = mkSpecialArgs system;
        };
    in {
      darwinConfigurations.macbook = mkDarwin { name = "macbook"; };

      nixosConfigurations.desktop = mkNixos { name = "desktop"; };

      nixosConfigurations.lenovo-ideapadslim3 = mkNixos {
        name = "lenovo-ideapadslim3";
        nixpkgsInput = nixpkgs-26_05;
        modules = [
          nixvim.nixosModules.default
        ];
      };

      nixosConfigurations.wsl = mkWsl { name = "default"; };
    };
}
