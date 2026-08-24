# Repository Guidelines

## Project Structure & Module Organization
- `flake.nix` – single entry point for nix-darwin, NixOS, WSL, and Home Manager outputs.
- `home/` – Home Manager entrypoint, host modules, reusable modules, and package groups; Home packages use `nixpkgs-unstable`.
- `system/hosts/` – host registry and per-machine system modules; keep host-specific tweaks here.
- `system/` – shared system profiles, modules, and overlays; profiles compose `nixos/base` into `headless`/`desktop`, and `headless` into `wsl`.
- `secrets/` – SOPS-encrypted data; `.sops.yaml` defines recipients. Never commit private keys.
- `scripts/` – bootstrap and one-time migration helpers such as SOPS age setup and SSH adoption.

## Build, Test, and Development Commands
- `nix flake check` – validates all system and Home Manager outputs.
- `darwin-rebuild switch --flake .#macbook` – apply macOS system changes.
- `nixos-rebuild switch --flake .#sg-lenovo` – apply NixOS system changes.
- `home-manager switch --flake .#dididi@sg-lenovo` – apply Home Manager changes.
- `SOPS_AGE_KEY_FILE=~/.config/sops/age/keys.txt sops secrets/<file>.yaml` – edit encrypted secrets locally.
- `./scripts/bootstrap-sops-age.sh` – install the local age identity before using `sops-nix` secrets.
- `./scripts/adopt-ssh-to-nix.sh` – move existing chezmoi-managed SSH files aside before first Nix-managed SSH activation.

## Coding Style & Naming Conventions
- Nix files use two-space indentation; align attribute sets vertically for readability.
- Home modules export options under `modules.<name>.*`; keep directory paths aligned with option prefixes (e.g., `modules.nvim`).
- Prefer descriptive camel-case flake outputs (`darwinConfigurations.macbook`, `homeConfigurations."dididi@macbook"`); host directories are lowercase kebab under `system/hosts/`.
- Keep package group logic declarative; avoid inline `.override` unless necessary—add helpers under `home/packages/`.

## Testing Guidelines
- Run `nix flake check` before every commit to catch evaluation regressions.
- For host-specific changes, build the target system (`darwin-rebuild build`, `nixos-rebuild build`) before switching.
- Home Manager module additions should compile with `nix eval --raw` or `home-manager switch --flake ... --dry-run` when possible.

## Commit & Pull Request Guidelines
- Use imperative, scoped commit subjects (e.g., `system: enable sops-nix` or `packages: add dev toolchain group`).
- Reference issue IDs in the body when applicable and summarize both motivation and impact.
- Pull requests should list rebuilt targets (e.g., “Run `darwin-rebuild switch` on macbook”) and mention any secrets or manual follow-up steps.
- Attach screenshots or config snippets when adjusting user-facing tooling (e.g., fish shell changes, GUI package updates).

## Security & Configuration Tips
- Keep `.sops.yaml` recipients aligned with the age identity installed by `scripts/bootstrap-sops-age.sh`.
- Store age private keys under `~/.config/sops/age/`; never commit them.
- Keep GUI apps in `home/packages/apps.nix`; the system layer should avoid duplicating Home Manager packages to maintain a single source of truth.
