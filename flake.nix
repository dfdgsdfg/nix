{
  description = "Declarative system and Home Manager configurations";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-26.05";
    nixpkgs-unstable.url = "github:nixos/nixpkgs/nixos-unstable";

    nix-darwin.url = "github:nix-darwin/nix-darwin/nix-darwin-26.05";
    nix-darwin.inputs.nixpkgs.follows = "nixpkgs";

    nixos-wsl.url = "github:nix-community/NixOS-WSL";
    nixos-wsl.inputs.nixpkgs.follows = "nixpkgs";

    nixvim.url = "github:nix-community/nixvim/nixos-26.05";
    nixvim.inputs.nixpkgs.follows = "nixpkgs";
    nix-wrapper-modules.url = "github:BirdeeHub/nix-wrapper-modules";
    nix-wrapper-modules.inputs.nixpkgs.follows = "nixpkgs-unstable";

    determinate.url = "https://flakehub.com/f/DeterminateSystems/determinate/3";

    home-manager.url = "github:nix-community/home-manager";
    home-manager.inputs.nixpkgs.follows = "nixpkgs-unstable";

    zen-browser.url = "github:0xc000022070/zen-browser-flake";
    zen-browser.inputs.nixpkgs.follows = "nixpkgs-unstable";

    claude-code-nix.url = "github:sadjow/claude-code-nix";
    claude-code-nix.inputs.nixpkgs.follows = "nixpkgs-unstable";

    herdr.url = "github:ogulcancelik/herdr";
    herdr.inputs.nixpkgs.follows = "nixpkgs-unstable";

    sops-nix.url = "github:Mic92/sops-nix";
    sops-nix.inputs.nixpkgs.follows = "nixpkgs";
  };

  outputs =
    inputs@{
      self,
      nixpkgs,
      nixpkgs-unstable,
      nix-darwin,
      home-manager,
      sops-nix,
      determinate,
      ...
    }:
    let
      lib = nixpkgs.lib;
      systemTargets = import ./system/targets.nix { inherit inputs; };
      homeTargets = import ./home/targets.nix;
      systems = lib.unique (
        map (target: target.system) (lib.attrValues systemTargets ++ lib.attrValues homeTargets)
      );

      mkSystemSpecialArgs = system: {
        inherit inputs;
        pkgsUnstable = import nixpkgs-unstable { inherit system; };
      };

      mkDarwin =
        host:
        nix-darwin.lib.darwinSystem {
          inherit (host) system;
          modules = host.modules ++ [
            determinate.darwinModules.default
            ./system/modules/packages.nix
            {
              system.configurationRevision = self.rev or self.dirtyRev or null;
            }
          ];
          specialArgs = mkSystemSpecialArgs host.system;
        };

      mkNixos =
        host:
        nixpkgs.lib.nixosSystem {
          inherit (host) system;
          modules = host.modules ++ [
            determinate.nixosModules.default
            sops-nix.nixosModules.sops
            ./system/modules/packages.nix
            ./system/modules/runtime.nix
            {
              system.configurationRevision = self.rev or self.dirtyRev or null;
            }
          ];
          specialArgs = mkSystemSpecialArgs host.system;
        };

      forAllSystems =
        f:
        lib.genAttrs systems (
          system:
          f (
            import nixpkgs-unstable {
              inherit system;
              config.allowUnfree = true;
            }
          )
        );

      mkHome =
        {
          system,
          username,
          homeDirectory,
          modules ? [ ./home/home.nix ],
          overlays ? [ ],
        }:
        let
          pkgs = import nixpkgs-unstable {
            inherit system overlays;
            config.allowUnfree = true;
          };
        in
        home-manager.lib.homeManagerConfiguration {
          inherit pkgs;
          modules = [
            sops-nix.homeManagerModules.sops
          ]
          ++ modules
          ++ [
            {
              home.username = username;
              home.homeDirectory = homeDirectory;
            }
          ];
          extraSpecialArgs = {
            inherit inputs;
            pkgsUnstable = pkgs;
          };
        };

      mkTargetHome =
        target:
        let
          platformModules =
            lib.optionals (lib.hasSuffix "-darwin" target.system) [ ./home/platforms/darwin.nix ]
            ++ lib.optionals (lib.hasSuffix "-linux" target.system) [ ./home/platforms/linux.nix ];
        in
        mkHome {
          inherit (target) system username homeDirectory;
          modules = platformModules ++ target.modules;
        };

      homeConfigurations = lib.mapAttrs' (
        name: target: lib.nameValuePair "${target.username}@${name}" (mkTargetHome target)
      ) homeTargets;

      mkActivationPackage =
        packages: name:
        let
          target = homeTargets.${name};
          configName = "${target.username}@${name}";
        in
        packages
        // {
          ${target.system} = (packages.${target.system} or { }) // {
            ${target.packageName} = homeConfigurations.${configName}.activationPackage;
          };
        };
    in
    {
      darwinConfigurations = lib.mapAttrs (_: mkDarwin) (
        lib.filterAttrs (_: target: target.type == "darwin") systemTargets
      );

      nixosConfigurations = lib.mapAttrs (_: mkNixos) (
        lib.filterAttrs (_: target: target.type == "nixos" || target.type == "wsl") systemTargets
      );

      inherit homeConfigurations;

      packages = lib.foldl' mkActivationPackage { } (lib.attrNames homeTargets);

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
