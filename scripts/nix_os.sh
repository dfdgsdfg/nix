#!/usr/bin/env bash
set -euo pipefail

target="/etc/nixos"
host="lenovo-ideapadslim3"
rebuild_action=""
dry_run=0

usage() {
  cat <<'EOF'
Usage: sudo scripts/nix_os.sh [options]

Copies this repository's NixOS system configuration into /etc/nixos.

Options:
  --target PATH          Target directory. Defaults to /etc/nixos.
  --host NAME            NixOS flake host. Defaults to lenovo-ideapadslim3.
  --rebuild ACTION       Run nixos-rebuild after copying: build, test, or switch.
  --dry-run              Print actions without changing files.
  -h, --help             Show this help.

After copying, rebuild with:
  sudo nixos-rebuild switch --flake 'path:/etc/nixos?dir=system#lenovo-ideapadslim3'
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --target)
      target="${2:?--target requires a path}"
      shift 2
      ;;
    --host)
      host="${2:?--host requires a name}"
      shift 2
      ;;
    --rebuild)
      rebuild_action="${2:?--rebuild requires build, test, or switch}"
      shift 2
      ;;
    --dry-run)
      dry_run=1
      shift
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      echo "Unknown argument: $1" >&2
      usage >&2
      exit 2
      ;;
  esac
done

case "$rebuild_action" in
  ""|build|test|switch) ;;
  *)
    echo "--rebuild must be one of: build, test, switch" >&2
    exit 2
    ;;
esac

script_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
repo_root="$(cd -- "${script_dir}/.." && pwd)"
marker=".managed-by-workspaces-nix"

require_path() {
  if [[ ! -e "$1" ]]; then
    echo "Required path is missing: $1" >&2
    exit 1
  fi
}

run() {
  if [[ "$dry_run" -eq 1 ]]; then
    printf '+'
    printf ' %q' "$@"
    printf '\n'
  else
    "$@"
  fi
}

require_path "${repo_root}/system/flake.nix"
require_path "${repo_root}/system/flake.lock"
require_path "${repo_root}/hosts/nixos/${host}/default.nix"

if [[ "$dry_run" -eq 0 && "${EUID}" -ne 0 ]]; then
  echo "Run as root, for example: sudo scripts/nix_os.sh" >&2
  exit 1
fi

if [[ -e "$target" && ! -e "${target}/${marker}" ]]; then
  backup="${target}.legacy-$(date +%Y%m%d%H%M%S)"
  echo "Backing up existing ${target} to ${backup}"
  run mv -- "$target" "$backup"
fi

run install -d -- "$target"
run rm -rf -- "${target}/system" "${target}/hosts"
run cp -a -- "${repo_root}/system" "${target}/system"
run cp -a -- "${repo_root}/hosts" "${target}/hosts"
run touch -- "${target}/${marker}"

flake_ref="path:${target}?dir=system#${host}"

if [[ -n "$rebuild_action" ]]; then
  run nixos-rebuild "$rebuild_action" --flake "$flake_ref"
else
  echo "Copied NixOS configuration to ${target}."
  echo "Next:"
  echo "  sudo nixos-rebuild build --flake ${flake_ref}"
  echo "  sudo nixos-rebuild test --flake ${flake_ref}"
  echo "  sudo nixos-rebuild switch --flake ${flake_ref}"
fi
