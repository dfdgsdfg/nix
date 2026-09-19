# Windows

Nix runs inside WSL and cannot reach the Windows side of the same machine, so
the Windows host is managed here instead: packages through winget and scoop
manifests, dotfiles through chezmoi, secrets through the SOPS files this repo
already carries.

## Division of labour

| Host | Managed by |
|---|---|
| macOS, NixOS, NixOS-WSL | nix / home-manager |
| Windows | this directory |

The two never overlap. `chezmoi/.chezmoiignore` ignores everything when
`.chezmoi.os` is not `windows`, so running `chezmoi apply` on a Mac or inside
WSL does nothing at all. This is a split of territory, not two systems competing
over one machine — which is the thing that made the earlier chezmoi setup worth
retiring when nix took over the Unix hosts.

## Secrets

Secrets stay in `secrets/*.yaml` under SOPS and are read from there. The legacy
chezmoi tree kept its own `encrypted_*.age` copies of the same keys; that is
deliberately not repeated, because the same secret in two formats is a secret
that can drift. Both use the same age recipient
(`age1zl2dssv…`), so one identity unlocks everything.

**Private keys are never written to the Windows filesystem.** `bootstrap.ps1`
decrypts the SSH key to a temp file, loads it into the Windows `ssh-agent`, and
deletes the file in a `finally` block. The agent keeps it encrypted under DPAPI
in the registry. A key file on NTFS would sit there permanently in the clear,
and Windows OpenSSH rejects key files whose ACLs are loose — which is exactly
the state `C:\Users\user\.ssh\id_ed25519` was found in.

The age identity itself is the one thing bootstrap cannot fetch for you. Copy it
once, from a host that has it:

```powershell
wsl.exe -d NixOS -- cat ~/.config/sops/age/keys.txt
# save to %USERPROFILE%\.config\sops\age\keys.txt
```

## Bootstrap

```powershell
# from the repo checkout
pwsh -File windows\bootstrap.ps1
```

Every step is guarded, so re-running only fills gaps. Enabling the `ssh-agent`
service needs one elevated run; everything else does not, and the script tells
you which case you are in.

```powershell
# skip package installs when only dotfiles changed
pwsh -File windows\bootstrap.ps1 -SkipPackages
```

## Packages

| File | Purpose |
|---|---|
| `packages/winget.json` | 15 intentionally installed packages; what `winget import` applies |
| `packages/winget-full.json` | Raw `winget export` for reference |
| `packages/scoop.json` | `scoop export` output |

`winget.json` drops transitive runtimes (`Microsoft.VCRedist*`, `VCLibs`,
`UI.Xaml`, `WindowsAppRuntime*`) and things that arrive with Windows or Office
(`Edge`, `OneDrive`, `Teams`, `Outlook`). They reappear in an export regardless
of whether anyone chose them, so declaring them adds churn without adding
control.

To refresh after installing something new:

```powershell
winget export -o windows\packages\winget-full.json --source winget
scoop export > windows\packages\scoop.json
# then curate winget.json by hand
```

## Dotfiles

`chezmoi/` is the source tree. `bootstrap.ps1` points chezmoi at it with
`--source`, so the state lives in this checkout rather than a second clone of
its own.

Managed today:

| Target | Source | Managed keys |
|---|---|---|
| `~/.pi/agent/settings.json` | `chezmoi/dot_pi/agent/modify_settings.json.py` | `defaultProvider`, `defaultModel`, `defaultThinkingLevel`, `enabledModels`, `theme` |
| `~/.pi/agent/models.json` | `chezmoi/dot_pi/agent/modify_models.json.py` | the whole `providers.omni` block |
| `~/.claude/settings.json` | `chezmoi/dot_claude/modify_settings.json.py` | `model`, `effortLevel` |

### Why `modify_` scripts call back into `home/modules/`

These agents write their own config at runtime — changelog versions, session
state, model overrides — so the managed keys have to be merged in rather than
the file replaced. Nix already does exactly that on the Unix hosts, in
`home/modules/*/merge-*.py`.

The scripts here import those same modules instead of restating the rules. A
PowerShell reimplementation would mean two definitions of "managed" and only one
of them getting updated. The cost is a real Python interpreter on Windows, which
`bootstrap.ps1` installs — note that the `python.exe` Windows ships in PATH is a
zero-byte Store stub, so the script checks that the interpreter actually
answers rather than merely resolving.

### The Pi API key

On macOS and NixOS, nix rewrites `providers.omni.apiKey` into a `!command` that
resolves through the OS keychain. Nothing equivalent is wired up on Windows yet,
so `modify_models.json.py` keeps whatever key is already in the file and only
updates the model catalogue around it. A fresh install gets a `REPLACE_ME`
placeholder; seed it once with the value from SOPS:

```powershell
sops -d --extract '["personal-pi"]' secrets\personal-agents.yaml
```

### Adding another agent

`codex` and `omp` are not wired up yet. The pattern is the same, but their merge
semantics differ and each needs its own adapter:

- **codex** — `~/.codex/config.toml`, merged per key by
  `home/modules/codex/merge-config.py` across the top level plus the `[agents]`
  and `[features]` sections. Its API key goes through a structured
  `auth.command` table, not a `!command` string.
- **omp** — `~/.omp/agent/config.yml` and `models.yml`, merged by whole
  top-level YAML block in `home/modules/omp/merge-config.py`.

## Not verified yet

This scaffold was built and tested from macOS against the repo's merge helpers.
The Python adapters were run directly and behave correctly for empty input,
existing runtime state and key preservation. `bootstrap.ps1` parses cleanly
under the Windows PowerShell parser.

What a first real run still has to confirm:

- that chezmoi strips the `.py` suffix from `modify_settings.json.py` to target
  `settings.json` once `[interpreters.py]` is configured
- `chezmoi init --source` against a tree that is not its own git clone
- that `sops` on Windows picks up the identity from `SOPS_AGE_KEY_FILE`
- `winget import` exit behaviour when every package is already current
