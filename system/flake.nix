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
    sops-nix.url = "github:Mic92/sops-nix";
    sops-nix.inputs.nixpkgs.follows = "nixpkgs";
    determinate.url = "https://flakehub.com/f/DeterminateSystems/determinate/3";
  };

  outputs = inputs@{ nixpkgs, nix-darwin, nixos-wsl, nixvim, nixpkgs-unstable, sops-nix, determinate, ... }:
    let
      lib = nixpkgs.lib;
      hosts = import ../hosts { inherit inputs; };

      mkSpecialArgs = system: {
        inherit inputs;
        isLinuxSystem = lib.hasSuffix "-linux" system;
        pkgsUnstable = import nixpkgs-unstable {
          inherit system;
        };
      };

      mkDarwin = host:
        nix-darwin.lib.darwinSystem {
          inherit (host) system;
          modules =
            host.systemModules
            ++ [
              ./modules/packages
              ({ ... }: {
                system.configurationRevision =
                  inputs.self.rev or inputs.self.dirtyRev or null;
              })
            ];
          specialArgs = mkSpecialArgs host.system;
        };

      mkNixos = host:
        nixpkgs.lib.nixosSystem {
          inherit (host) system;
          modules =
            host.systemModules
            ++ [
              determinate.nixosModules.default
            ]
            ++ [
              sops-nix.nixosModules.sops
              ./modules/packages
              ({ ... }: {
                system.configurationRevision =
                  inputs.self.rev or inputs.self.dirtyRev or null;
              })
            ];
          specialArgs = mkSpecialArgs host.system;
        };
    in {
      darwinConfigurations =
        lib.mapAttrs
          (_: mkDarwin)
          (lib.filterAttrs (_: host: (host.systemEnabled or true) && host.type == "darwin") hosts);

      nixosConfigurations =
        lib.mapAttrs
          (_: mkNixos)
          (lib.filterAttrs (_: host: (host.systemEnabled or true) && (host.type == "nixos" || host.type == "wsl")) hosts);
    };
}
