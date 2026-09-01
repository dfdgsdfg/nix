{
  # Lower values are evaluated first. Home Manager prepends the complete
  # sessionPath to the inherited Nix and OS PATH.
  userBin = 100;
  mise = 200;
  userPackage = 300;
  userOpt = 400;
  userExtra = 450;
  sdk = 500;
  compilerWrapper = 600;
  homebrew = 700;
}
