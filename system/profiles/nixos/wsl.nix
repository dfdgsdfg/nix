{ inputs, ... }:
{
  imports = [
    ./headless.nix
    inputs.nixos-wsl.nixosModules.wsl
  ];
  nix.registry.unstable.flake = inputs.nixpkgs-unstable;
  wsl.enable = true;
  wsl.defaultUser = "dididi";
  wsl.startMenuLaunchers = false;

  # WSL enters the distro without a PAM login, so logind never opens a session
  # and user@1000.service stays inactive. XDG_RUNTIME_DIR is then set but
  # /run/user/1000 does not exist, which breaks `systemctl --user` and leaves
  # sops-nix unable to resolve its `%r/secrets.d` mount point -- every ~/.ssh
  # key ends up a dangling symlink. Lingering starts the user manager without
  # a session.
  users.users.dididi.linger = true;

  # Allow mise-managed runtimes such as Node to execute their upstream
  # dynamically linked Linux binaries on NixOS.
  modules.runtime.nixLd.enable = true;

  services.tailscale.enable = false;
  systemd.services.cloudflared.enable = false;
}
