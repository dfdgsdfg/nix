#!/usr/bin/env bash
set -euo pipefail

backup_root="${SSH_NIX_BACKUP_DIR:-$HOME/.ssh/chezmoi-backup-$(date +%Y%m%d%H%M%S)}"

paths=(
  "$HOME/.ssh/authorized_keys"
  "$HOME/.ssh/config"
  "$HOME/.ssh/config.d/hosts.conf"
  "$HOME/.ssh/id_ed25519"
  "$HOME/.ssh/id_ed25519.pub"
  "$HOME/.ssh/id_rsa"
  "$HOME/.ssh/id_rsa.pub"
  "$HOME/.ssh/id_rsa.pub.pem"
  "$HOME/.ssh/readonly_id_rsa"
  "$HOME/.ssh/readonly_id_rsa.pub"
  "$HOME/.ssh/readonly_id_rsa.pub.pem"
)

install -d -m 700 "$HOME/.ssh"
install -d -m 700 "$backup_root"

for path in "${paths[@]}"; do
  if [[ -e "$path" || -L "$path" ]]; then
    rel="${path#$HOME/.ssh/}"
    install -d -m 700 "$backup_root/$(dirname "$rel")"
    mv "$path" "$backup_root/$rel"
  fi
done

printf 'Moved existing SSH files to %s\n' "$backup_root"
printf 'Run Home Manager activation after this so sops-nix can create managed SSH files.\n'
