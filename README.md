# Nix Configurations

This repository contains system and Home Manager configurations for macOS,
NixOS, and WSL hosts.

## Layout

- `system/flake.nix` evaluates nix-darwin, NixOS, and WSL systems.
- `hosts/default.nix` is the host registry shared by system and Home Manager flakes.
- `hosts/{darwin,nixos,wsl}/` contains host-specific system modules.
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
nixos-rebuild build --flake ./system#sg-lenovo
home-manager build --flake ./home#dididi@sg-lenovo
```

## Codex agent routing

`modules/codex` keeps the Codex main agent on GPT-5.6 Sol with medium
reasoning, defaults subagents to GPT-5.6 Luna with high reasoning, and defines
the `worker`, `explorer`, `tester`, and `powerhouse` roles. The module merges
only these owned keys into `~/.codex/config.toml`, leaving app-managed MCP,
plugin, notice, and project settings mutable.

The Sol Medium parent, built-in `default`, and Sol High `powerhouse` use the
Standard service tier. Custom Luna roles explicitly use Fast mode.

## SOPS Bootstrap

Secrets are encrypted for the age recipient listed in `.sops.yaml`. A fresh
machine needs the matching age identity before Home Manager can decrypt secrets.

```bash
./scripts/bootstrap-sops-age.sh
```

The script installs `~/.config/sops/age/keys.txt` from `~/key.txt` when present,
or prompts for the age identity. Do not commit the age identity.

## Chezmoi Migration

Home Manager profiles manage migrated chezmoi secrets through `sops-nix`. Git
user include files and fish credentials are written under `~/.config`, while
Darwin and Lenovo profiles manage selected SSH files under `~/.ssh`.

Existing SSH files from the old chezmoi setup must be moved out of the way once
before activating a profile that manages SSH:

```bash
./scripts/adopt-ssh-to-nix.sh
home-manager switch --flake ./home#dididi@sg-lenovo
```

The adoption script moves existing SSH files into a timestamped backup directory
under `~/.ssh`. It does not delete keys.
