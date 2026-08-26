{ inputs }:

{
  sg-macbook = {
    type = "darwin";
    system = "aarch64-darwin";
    modules = [ ./hosts/darwin/sg-macbook ];
  };

  us-mbpro2311-sg = {
    type = "darwin";
    system = "aarch64-darwin";
    modules = [ ./hosts/darwin/us-mbpro2311-sg ];
  };

  sg-lenovo = {
    type = "nixos";
    system = "x86_64-linux";
    modules = [ ./hosts/nixos/sg-lenovo ];
  };

  sg-asus = {
    type = "wsl";
    system = "x86_64-linux";
    modules = [ ./hosts/wsl/sg-asus ];
  };
}
