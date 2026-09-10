# Nix Configurations

This repository contains system and Home Manager configurations for macOS,
NixOS, and WSL hosts.

## Layout

- `flake.nix` evaluates nix-darwin, NixOS, WSL, and Home Manager outputs.
- `system/targets.nix` and `home/targets.nix` independently declare system and Home Manager targets.
- `system/hosts/{darwin,nixos,wsl}/` contains host-specific system modules.
- `system/profiles/` contains reusable system roles: `nixos/base`, `nixos/headless` → `nixos/wsl`, `nixos/desktop`, and `darwin/base`.
- `home/profiles/` composes reusable Home Manager roles such as `personal` and `nixos/desktop`.
- `home/hosts/` contains machine-specific Home Manager settings and imports profiles inward.
- `home/modules/` contains leaf Home Manager modules; modules do not import profiles or hosts.
- `secrets/` contains SOPS-encrypted data consumed by `sops-nix`.
- `scripts/` contains bootstrap and one-time migration helpers.

Linux desktop modules are intentionally host-scoped. macOS and WSL should opt in
to extra GUI, game, Android, GNOME, or SSH modules explicitly instead of getting
them from the shared Home Manager base.

## Checks

```bash
nix flake check
```

For host-specific changes, build the target before switching when practical:

```bash
nixos-rebuild build --flake .#sg-lenovo
home-manager build --flake .#dididi@sg-lenovo
```

## Codex agent routing

`home/modules/codex` keeps the Codex main agent on GPT-6 Astra with medium reasoning,
defaults unspecified subagents to GPT-5.6 Luna with high reasoning, and defines
the `scout`, `explorer`, `worker`, and `powerhouse` roles. The module merges only
these owned keys into `~/.codex/config.toml`, leaving app-managed MCP, plugin,
notice, and project settings mutable.

OmniRoute API routing is opt-in with the native profile selector:

```bash
codex -p omni-api
codex -p omni-api -m model/gpt-6-astra
```

The managed `~/.codex/omni-api.config.toml` uses command-backed authentication.
Activation also merges the profile into existing Orca account homes, preserving
profile-local UI state. Run Home Manager again after adding a new Orca account.
An API-specific catalog maps installed Codex metadata to the five `model/*`
route names so model selection and subagent validation use the same IDs.
The SOPS-encrypted `secrets/codex.yaml` seeds the native keychain on first use
and refreshes it after rotation. Darwin uses login Keychain; Linux requires an
unlocked Secret Service accessible through `secret-tool`.
Credentials are never written to the Nix store or the profile TOML.

Spark High `scout`, Terra Medium `explorer`, the Astra Medium parent, and Astra XHigh
`powerhouse` use the Standard service tier. Luna High `worker` uses Fast mode.

## Claude agent routing

`home/modules/claude` pins the Claude main session to Opus with high effort and
defines `scout`, `Explore`, `general-purpose`, and `powerhouse`. The exact
`Explore` and `general-purpose` names override Claude Code's built-in agents,
keeping broad exploration on Sonnet Medium and implementation on Sonnet High.
The module merges only `model` and `effortLevel` into
`~/.claude/settings.json`, leaving hooks, plugins, permissions, and other
app-managed state mutable.

## SOPS Bootstrap

Existing hosts opt into `home/profiles/personal.nix`. It composes the personal
SSH profile, SOPS secrets, Git identity include, fish credential loading, age
key environment variable, and encrypted jj identity on Darwin and Linux. Common tooling remains in
`home/home.nix`.

Personal credentials use machine-independent names: `personal-codex`,
`personal-pi`, and `personal-omp`. Codex reads `secrets/codex.yaml`; Pi and OMP
read separate entries in `secrets/personal-agents.yaml`. Each client shares its
own credential across personal machines and has a distinct runtime file and
OS keychain entry (`omniroute-personal-<client>`). The helpers seed Darwin
Keychain or Linux Secret Service from the private SOPS paths.

OmniRoute uses the same `personal-codex`, `personal-pi`, and `personal-omp`
key names. Codex is restricted to the five subscription-only model routes;
Pi and OMP have separate operator route grants and usage attribution. The old
`api` Codex profile is retained locally for compatibility; activation seeds
`omni-api` from its managed OmniRoute settings without changing default login
configuration.

For a machine that only needs shared tooling, import `home/home.nix` and the
desired package groups from its target/host configuration, but omit the
`personal` profile. Supply its own Git identity separately; the personal age
key and SSH credentials are not required by the common configuration.

`home/profiles/work-us.nix` independently opts into the US work SSH identity
`~/.ssh/us_sg_ed25519` and its public key, encrypted in `secrets/work-us.yaml`.
Import it from the hosts that need this key; it does not require the `personal`
profile or change which identity SSH selects for a host. Set `IdentityFile` in
the relevant SSH host rule to use it. Currently only `us-mbpro2311-sg` imports
this profile. Before the first activation, back up any
existing files at these paths and move them aside for SOPS-managed links.

Secrets are encrypted for the age recipient listed in `.sops.yaml`. A fresh
machine using either secret-bearing profile needs the matching age identity before
Home Manager can decrypt secrets.

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
home-manager switch --flake .#dididi@sg-lenovo
```

The adoption script moves existing SSH files into a timestamped backup directory
under `~/.ssh`. It does not delete keys.
