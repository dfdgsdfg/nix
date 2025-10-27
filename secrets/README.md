# Secrets

This directory stores SOPS-encrypted secrets that can be deployed through
`sops-nix`.

## Getting started

1. Install `age` and `sops` (already referenced in the Home Manager profile).
2. Generate an age key pair and store it locally (never commit the private key):

   ```bash
   mkdir -p ~/.config/sops/age
   age-keygen -o ~/.config/sops/age/keys.txt
   ```

3. Add the public key printed by `age-keygen` to `.sops.yaml` under the
   `keys` section (replace the existing placeholder).
4. Re-encrypt `secrets/example.yaml` or add your own secrets. For example:

   ```bash
   SOPS_AGE_KEY_FILE=~/.config/sops/age/keys.txt sops secrets/example.yaml
   ```

5. Update modules or Home Manager to consume the new secret paths as needed.

> The committed key in `.sops.yaml` is a placeholder for bootstrapping.
> Replace it with your own recipient before storing real secrets.

## SSH keys

SSH keys are sourced from `secrets/ssh.yaml` and surfaced through the `modules.ssh`
Home Manager module. Run the following to edit or replace the placeholders:

```bash
SOPS_AGE_KEY_FILE=~/.config/sops/age/keys.txt sops secrets/ssh.yaml
```

Populate the `ssh.github.id_ed25519` and `ssh.github.id_ed25519_pub` entries with your
private and public keys respectively. The module writes the decrypted private key to
`~/.ssh/github_ed25519` and wires it into the generated SSH config.
