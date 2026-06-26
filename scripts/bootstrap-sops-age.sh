#!/usr/bin/env bash
set -euo pipefail

target="${SOPS_AGE_KEY_FILE:-$HOME/.config/sops/age/keys.txt}"
legacy_source="${LEGACY_AGE_KEY_FILE:-$HOME/key.txt}"

install -d -m 700 "$(dirname "$target")"

if [[ -f "$target" ]]; then
  chmod 600 "$target"
elif [[ -f "$legacy_source" ]]; then
  install -m 600 "$legacy_source" "$target"
else
  umask 077
  printf 'Paste age identity for sops-nix, then press Ctrl-D:\n' >&2
  cat > "$target"
  chmod 600 "$target"
fi

if command -v age-keygen >/dev/null 2>&1; then
  printf 'Installed SOPS age identity: %s\n' "$(age-keygen -y "$target")"
else
  printf 'Installed SOPS age identity at %s\n' "$target"
fi
