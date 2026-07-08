# Secrets

This directory stores SOPS-encrypted secrets that can be deployed through
`sops-nix`.

## Age Identity

The committed SOPS files are encrypted for the age recipient in `.sops.yaml`.
A machine must have the matching private age identity before Home Manager can
activate profiles that consume secrets.

Install the identity locally:

```bash
./scripts/bootstrap-sops-age.sh
```

The script copies `~/key.txt` when it exists, or prompts for an age identity.
It writes `~/.config/sops/age/keys.txt` with mode `0600`.

## Editing Secrets

```bash
SOPS_AGE_KEY_FILE=~/.config/sops/age/keys.txt sops secrets/<file>.yaml
```

When adding a new secret file, make sure its path matches `.sops.yaml` creation
rules and that the file is encrypted for the current recipient.

## Home secrets

Git user includes and fish credentials are sourced from `secrets/home.yaml` and
written back to their chezmoi-compatible paths:

- `~/.config/git/config-user`
- `~/.config/git/config-user-work`
- `~/.config/git/config-user-work-us`
- `~/.config/fish/credential.fish`

Edit them with:

```bash
SOPS_AGE_KEY_FILE=~/.config/sops/age/keys.txt sops secrets/home.yaml
```

## SSH keys

SSH keys are sourced from `secrets/ssh.yaml` and surfaced through the `modules.ssh`
Home Manager module. Run the following to edit or replace them:

```bash
SOPS_AGE_KEY_FILE=~/.config/sops/age/keys.txt sops secrets/ssh.yaml
```

The Lenovo Linux home profile writes decrypted SSH keys and include files under
`~/.ssh` with SSH-safe modes. Before the first activation on a machine already
managed by chezmoi, run:

```bash
./scripts/adopt-ssh-to-nix.sh
```

This moves existing SSH files to a timestamped backup directory so `sops-nix` can
create the managed paths during Home Manager activation.

The current Lenovo profile manages:

- `~/.ssh/id_ed25519`
- `~/.ssh/id_ed25519.pub`
- `~/.ssh/id_rsa`
- `~/.ssh/id_rsa.pub`
- `~/.ssh/id_rsa.pub.pem`
- `~/.ssh/authorized_keys`
- `~/.ssh/config`
- `~/.ssh/config.d/hosts.conf`
