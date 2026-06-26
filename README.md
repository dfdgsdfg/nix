# Nix Configurations

This repository contains system and Home Manager configurations for macOS,
NixOS, and WSL hosts.

## Layout

- `system/flake.nix` evaluates nix-darwin, NixOS, and WSL systems.
- `hosts/` contains host-specific system modules.
- `home/flake.nix` evaluates Home Manager profiles.
- `home/hosts/nixos/lenovo-ideapadslim3/` contains Linux desktop Home Manager modules migrated from the old `~/hm` setup.
- `modules/` contains reusable Home Manager modules.
- `packages/` contains grouped Home Manager package selections.
- `secrets/` contains SOPS-encrypted data consumed by `sops-nix`.
- `scripts/` contains bootstrap and one-time migration helpers.

Linux desktop modules are intentionally host-scoped. macOS and WSL should opt in
to extra GUI, game, Android, GNOME, or SSH modules explicitly instead of getting
them from the shared Home Manager base.

## Checks

```bash
nix flake check ./system
nix flake check ./home
```

For host-specific changes, build the target before switching when practical:

```bash
nixos-rebuild build --flake ./system#lenovo-ideapadslim3
home-manager build --flake ./home#dididi@lenovo-ideapadslim3
```

## SOPS Bootstrap

Secrets are encrypted for the age recipient listed in `.sops.yaml`. A fresh
machine needs the matching age identity before Home Manager can decrypt secrets.

```bash
./scripts/bootstrap-sops-age.sh
```

The script installs `~/.config/sops/age/keys.txt` from `~/key.txt` when present,
or prompts for the age identity. Do not commit the age identity.

## SSH Migration

The Lenovo Linux Home Manager profile manages SSH keys and selected SSH files
through `sops-nix`. Existing files from the old chezmoi setup must be moved out
of the way once before activation:

```bash
./scripts/adopt-ssh-to-nix.sh
home-manager switch --flake ./home#dididi@lenovo-ideapadslim3
```

The adoption script moves existing SSH files into a timestamped backup directory
under `~/.ssh`. It does not delete keys.

