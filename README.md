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

## Orca CLI on Linux

The desktop package includes `orca-ui` for the app and `orca-ide` for its CLI.
The CLI uses an FHS environment for Electron's shared libraries and runs the
bundled CLI launcher directly, without the desktop launcher's GUI flags.
Home Manager owns `~/.local/bin/orca-ide` and the `~/.local/bin/orca` compatibility
entry point so both follow the installed version after upgrades and garbage
collection.

```bash
orca-ide skills get orca-cli
orca-ide status --json
```

The SSH module installs Home Manager's generated `~/.ssh/config` as a
user-owned regular file with mode `0600` on every activation. Orca's FHS user
namespace displays the Nix store owner as `nobody`, which OpenSSH rejects for
this config file. Change SSH settings in `home/modules/ssh` or
`home/profiles/ssh.nix`; activation replaces local edits to `~/.ssh/config`.

## Checks

```bash
nix flake check
```

For host-specific changes, build the target before switching when practical:

```bash
nixos-rebuild build --flake .#sg-lenovo
home-manager build --flake .#dididi@sg-lenovo
```

## Dependency updates

GitHub Actions runs Renovate on Monday, Wednesday, and Friday at 21:00 KST or by manual dispatch.
Actions owns scheduling; Renovate has no additional time window, including for
flake.lock maintenance, so delayed runs still process updates. Hourly and
concurrent PR creation are unlimited. Individual dependency updates require three
days of release age where available. Native Nix `flake.lock` maintenance is exempt
from that delay; channel and individual dependency upgrades retain it. Major
upgrades require Dependency Dashboard approval, and merging remains manual.

Supported upstream binary updates run `scripts/renovate-release-hashes.py` through
Renovate's `postUpgradeTasks` before committing. The hook downloads the updated
release with `nix store prefetch-file`, refreshes every declared Linux and Darwin
hash, and includes those edits in the same PR. It only writes after all downloads
succeed. These branches rebase when behind `main`, so existing PRs receive new
hook configuration. The workflow permits only this exact hook command.

The supported dependency registry is in the script; its package names and file
paths must match the hook rule in `renovate.json`. Run
`python3 scripts/test-renovate-release-hashes.py` to check coverage and layouts.
Source archives (`fetchFromGitHub`/`fetchzip`) and dependency hashes remain manual:
their updates keep `needs-hash` and require refreshed hashes and a build before
merging. Binary updates also require successful CI before merging.

FlakeHub inputs, including Determinate and its transitive dependencies, update
through native `flake.lock` maintenance. Individual Git lookups for Determinate
and the native manager's `nixpkgs` entry are disabled: Renovate does not recognize
FlakeHub tarballs, and its lock-node lookup can mistake a transitive `nixpkgs`
for the root input. A regex manager reads the stable `nixpkgs` channel directly
from `flake.nix`, preserving channel-upgrade PRs; the native Nix manager still
refreshes `flake.lock` for those changes. Channel upgrades do not need the
`needs-hash` label. Lock maintenance stays within the input ranges in
`flake.nix`; changing Determinate's major range remains an explicit edit.

Renovate refreshes an existing update branch when a newer release supersedes
its target. Separate major and minor upgrade paths may have separate PRs;
package name alone is not a reason to close one.

## Codex agent routing

`home/modules/codex` keeps the Codex main agent on GPT-6.1 Sol with high reasoning (including Plan mode),
defaults unspecified subagents to GPT-6 Luna with high reasoning, and defines
the `scout`, `explorer`, `worker`, and `powerhouse` roles. The module merges only
these owned keys into `~/.codex/config.toml`, leaving app-managed MCP, plugin,
notice, and project settings mutable.

OmniRoute API routing is opt-in with the native profile selector:

```bash
codex -p omni-api
codex -p omni-api -m model/gpt-6.1-sol
```

The managed `~/.codex/omni-api.config.toml` uses command-backed authentication.
Activation also merges the profile into existing Orca account homes, preserving
profile-local UI state. Run Home Manager again after adding a new Orca account.
An API-specific catalog maps installed Codex metadata to the four `model/*`
route names so model selection and subagent validation use the same IDs.
The SOPS-encrypted `secrets/codex.yaml` seeds the native keychain on first use
and refreshes it after rotation. Darwin uses login Keychain; Linux requires an
unlocked Secret Service accessible through `secret-tool`.
Credentials are never written to the Nix store or the profile TOML.

Spark 5.3/high `scout`, Sol 6.1/medium `explorer`, Sol 6.1/high Main, and
Astra 6/xhigh `powerhouse` do not pin a service tier. Luna 6/high `worker`
uses Fast mode. The OmniRoute profile derives the same roles with `omni-` names
and `model/` model IDs.

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
key names. Codex is restricted to the managed subscription model routes;
Pi and OMP have separate operator route grants and usage attribution. The old
`api` Codex profile is retained locally for compatibility; activation seeds
`omni-api` from its managed OmniRoute settings without changing default login
configuration.

The `omni-api` profile has separate `omni-scout`, `omni-explorer`,
`omni-worker`, and `omni-powerhouse` roles. Its developer instructions map
the usual role names to these OmniRoute roles, avoiding collisions with
automatically discovered subscription roles in `~/.codex/agents/`.
Edit `home/modules/codex/omni-api-agents.md` for API-specific delegation rules.

For a machine that only needs shared tooling, import `home/home.nix` and the
desired package groups from its target/host configuration, but omit the
`personal` profile. Supply its own Git identity separately; the personal age
key and SSH credentials are not required by the common configuration.

The personal SSH profile trusts the homelab agent through the public-only
`home/modules/ssh/agent.pub`. A SOPS template combines the existing encrypted
authorized-key list with this public key at `~/.ssh/authorized_keys`. This is
inbound client authorization; `known_hosts` instead authenticates destination
SSH servers. Applying the profile does not enable a disabled SSH server.

The homelab repository owns generation and credential management through
`scripts/provision-agent-ssh.py`, OCI Vault secret `homelab-agent-ssh-key`, and
canonical public key `nix/keys/agent.pub`. This repository keeps only a public
trust copy; it neither stores nor installs the agent's private key. Keep the
public copy aligned with homelab when intentionally rotating the identity.
The agent inherits the existing destination account's permissions.

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

## RustDesk clients

The personal Home Manager profile installs `rustdesk-homelab` and a public server
profile at `~/.config/rustdesk-homelab/`. Native clients still come from Homebrew
(macOS), the desktop AppImage (NixOS), and Scoop (Windows). WSL is not a separate
remote desktop: enroll the Windows host instead.

After applying Home Manager, join Tailscale, export the client's previous server
configuration for rollback, then copy the output below into RustDesk Settings →
Network → Unlock Network Settings → Import Server Config:

```sh
rustdesk-homelab config
```

The profile selects `oci-default-01.tail484abe.ts.net:21116` and the verified hbbs
public key; relay and API fields are blank. An installed RustDesk service can
also import the string using `rustdesk --config '<string>'` with administrative
privileges. Upstream requires an installed client and elevation for that CLI;
the NixOS AppImage should use GUI import. Home Manager does not overwrite mutable
RustDesk TOML files or change settings through a privileged activation hook.
Confirm Ready and the device ID after import. Configure access passwords outside
Git; macOS also needs Screen Recording and Accessibility permissions.

Record each device's actual RustDesk ID in `home/modules/rustdesk/clients.json`
and reapply Home Manager to distribute the list. Null means not yet enrolled;
no synthetic IDs are assigned. `us-mbpro2311-sg` was read locally using
`RustDesk --get-id`; recheck it after enrolling with the homelab server. Every generated destination includes the server
and public key, including when the default server is already homelab:

```sh
rustdesk-homelab list
rustdesk-homelab address 123456789
rustdesk-homelab connect 123456789
# After recording its ID:
rustdesk-homelab connect sg-lenovo
```

`address` prints `ID@server:21116?key=public-key`; `connect` passes that exact
address to RustDesk. This is an outbound connection selector, not a custom ID or
simultaneous registration with multiple servers. These commands do not populate
RustDesk's internal recent-peer database. To undo enrollment, import the saved
previous server configuration. No unattended-access passwords are managed here.
