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

    determinate.url = "https://flakehub.com/f/DeterminateSystems/determinate/3";

    home-manager.url = "github:nix-community/home-manager";
    home-manager.inputs.nixpkgs.follows = "nixpkgs-unstable";

    zen-browser.url = "github:0xc000022070/zen-browser-flake";
    zen-browser.inputs.nixpkgs.follows = "nixpkgs-unstable";

    claude-code-nix.url = "github:sadjow/claude-code-nix";
    claude-code-nix.inputs.nixpkgs.follows = "nixpkgs-unstable";

    codex-cli-nix.url = "github:sadjow/codex-cli-nix";
    codex-cli-nix.inputs.nixpkgs.follows = "nixpkgs-unstable";

    herdr.url = "github:ogulcancelik/herdr";
    herdr.inputs.nixpkgs.follows = "nixpkgs-unstable";

    sops-nix.url = "github:Mic92/sops-nix";
    sops-nix.inputs.nixpkgs.follows = "nixpkgs";
  };

  outputs = inputs@{
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
      hosts = import ./system/hosts { inherit inputs; };
      systems = lib.unique (map (host: host.system) (lib.attrValues hosts));

      mkSystemSpecialArgs = system: {
        inherit inputs;
        isLinuxSystem = lib.hasSuffix "-linux" system;
        pkgsUnstable = import nixpkgs-unstable { inherit system; };
      };

      mkDarwin = host:
        nix-darwin.lib.darwinSystem {
          inherit (host) system;
          modules = host.systemModules ++ [
            ./system/modules/packages
            {
              system.configurationRevision = self.rev or self.dirtyRev or null;
            }
          ];
          specialArgs = mkSystemSpecialArgs host.system;
        };

      mkNixos = host:
        nixpkgs.lib.nixosSystem {
          inherit (host) system;
          modules = host.systemModules ++ [
            determinate.nixosModules.default
            sops-nix.nixosModules.sops
            ./system/modules/packages
            {
              system.configurationRevision = self.rev or self.dirtyRev or null;
            }
          ];
          specialArgs = mkSystemSpecialArgs host.system;
        };

      forAllSystems = f:
        lib.genAttrs systems (system:
          f (import nixpkgs-unstable {
            inherit system;
            config.allowUnfree = true;
          }));

      mkHome = {
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
          modules = [ sops-nix.homeManagerModules.sops ] ++ modules ++ [
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

      mkHostHome = host:
        let
          platformModules =
            lib.optionals (lib.hasSuffix "-darwin" host.system) [ ./home/platforms/darwin.nix ]
            ++ lib.optionals (lib.hasSuffix "-linux" host.system) [ ./home/platforms/linux.nix ];
        in
        mkHome {
          inherit (host) system username homeDirectory;
          modules = platformModules ++ host.homeModules;
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
    in
    {
      darwinConfigurations =
        lib.mapAttrs
          (_: mkDarwin)
          (lib.filterAttrs (_: host: (host.systemEnabled or true) && host.type == "darwin") hosts);

      nixosConfigurations =
        lib.mapAttrs
          (_: mkNixos)
          (lib.filterAttrs (_: host: (host.systemEnabled or true) && (host.type == "nixos" || host.type == "wsl")) hosts);

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
