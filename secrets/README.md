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
