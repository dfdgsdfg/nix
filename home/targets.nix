{
  sg-macbook = {
    system = "aarch64-darwin";
    username = "dididi";
    homeDirectory = "/Users/dididi";
    modules = [
      ./home.nix
      ./hosts/darwin/sg-macbook
    ];
    packageName = "sg-macbook";
  };

  us-mbpro2311-sg = {
    system = "aarch64-darwin";
    username = "dididi";
    homeDirectory = "/Users/dididi";
    modules = [
      ./home.nix
      ./hosts/darwin/us-mbpro2311-sg
    ];
    packageName = "us-mbpro2311-sg";
  };

  sg-lenovo = {
    system = "x86_64-linux";
    username = "dididi";
    homeDirectory = "/home/dididi";
    modules = [
      ./home.nix
      ./hosts/nixos/sg-lenovo
    ];
    packageName = "sg-lenovo";
  };

  sg-asus = {
    system = "x86_64-linux";
    username = "dididi";
    homeDirectory = "/home/dididi";
    modules = [
      ./home.nix
      ./hosts/wsl/sg-asus
    ];
    packageName = "sg-asus";
  };
}
