# Repository Guidelines

## Project Structure & Module Organization
- `system/flake.nix` – entry point for nix-darwin, NixOS, and WSL hosts; pulls host modules from `hosts/`.
- `hosts/{darwin,nixos,wsl}/` – per-machine system modules; keep host-specific tweaks here.
- `home/flake.nix` – Home Manager flake exporting each user profile; shared logic lives in `home/home.nix`.
- `modules/` – reusable home modules (e.g., `modules/nvim` for LazyVim).
- `packages/` – grouped package selections (`default.nix` toggles core/dev/etc.; `apps.nix` handles macOS GUI apps).
- `secrets/` – SOPS-encrypted data; `.sops.yaml` defines recipients. Never commit private keys.

## Build, Test, and Development Commands
- `nix flake check ./system` – validates system modules (darwin/NixOS/WSL) for evaluation errors.
- `nix flake check ./home` – evaluates Home Manager configurations.
- `darwin-rebuild switch --flake ./system#macbook` – apply macOS system changes.
- `nixos-rebuild switch --flake ./system#desktop` / `nix run .#homeConfigurations."dididi@macbook".activationPackage` – deploy NixOS or Home Manager updates.
- `SOPS_AGE_KEY_FILE=~/.config/sops/age/keys.txt sops secrets/<file>.yaml` – edit encrypted secrets locally.

## Coding Style & Naming Conventions
- Nix files use two-space indentation; align attribute sets vertically for readability.
- Home modules export options under `modules.<name>.*`; keep directory paths aligned with option prefixes (e.g., `modules.nvim`).
- Prefer descriptive camel-case flake outputs (`darwinConfigurations.macbook`, `homeConfigurations."dididi@macbook"`); host files are lowercase kebab (`hosts/darwin/macbook.nix`).
- Keep package group logic declarative; avoid inline `.override` unless necessary—add helpers under `packages/`.

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
- Replace placeholder Age recipients in `.sops.yaml` before storing real secrets.
- Store private keys under `~/.config/sops/age/`; ensure they are ignored (`secrets/.gitignore`).
- Keep GUI apps in `packages/apps.nix`; the system layer should avoid duplicating Home Manager packages to maintain a single source of truth.
