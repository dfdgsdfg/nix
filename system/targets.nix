{ inputs }:

{
  sg-macbook = {
    type = "darwin";
    system = "aarch64-darwin";
    modules = [ ./hosts/darwin/sg-macbook ];
  };

  sg-lenovo = {
    type = "nixos";
    system = "x86_64-linux";
    modules = [
      ./hosts/nixos/lenovo-ideapadslim3
      inputs.nixvim.nixosModules.default
    ];
  };

  sg-asus = {
    type = "wsl";
    system = "x86_64-linux";
    modules = [ ./hosts/wsl/sg-asus ];
  };
}
