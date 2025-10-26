{
  description = "Declarative systems for darwin, NixOS, and WSL hosts";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-25.05";
    nix-darwin.url = "github:nix-darwin/nix-darwin/nix-darwin-25.05";
    nix-darwin.inputs.nixpkgs.follows = "nixpkgs";
    nixpkgs-unstable.url = "github:nixos/nixpkgs/nixos-unstable";
    home-manager.url = "github:nix-community/home-manager/release-25.05";
    home-manager.inputs.nixpkgs.follows = "nixpkgs";
    nixos-wsl.url = "github:nix-community/NixOS-WSL";
    nixos-wsl.inputs.nixpkgs.follows = "nixpkgs";
    sops-nix.url = "github:Mic92/sops-nix";
    sops-nix.inputs.nixpkgs.follows = "nixpkgs";
  };

  outputs = inputs@{ nixpkgs, nix-darwin, home-manager, nixos-wsl, sops-nix, nixpkgs-unstable, ... }:
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

      mkNixos = { name, system ? "x86_64-linux", modules ? [ ] }:
        nixpkgs.lib.nixosSystem {
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

      nixosConfigurations.wsl = mkWsl { name = "default"; };
    };
}
