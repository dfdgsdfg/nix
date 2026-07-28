#!/usr/bin/env bash
set -euo pipefail

profile="${1:-/nix/var/nix/profiles/system}"
keep_generations="${2:-5}"
max_age_days="${3:-30}"

if [[ ! "$keep_generations" =~ ^[1-9][0-9]*$ ]]; then
  printf 'keep_generations must be a positive integer: %s\n' "$keep_generations" >&2
  exit 2
fi

if [[ ! "$max_age_days" =~ ^[1-9][0-9]*$ ]]; then
  printf 'max_age_days must be a positive integer: %s\n' "$max_age_days" >&2
  exit 2
fi

if [[ ! -L "$profile" ]]; then
  printf 'Skipping generation pruning; profile does not exist: %s\n' "$profile"
  exit 0
fi

profile_dir="$(dirname -- "$profile")"
profile_name="$(basename -- "$profile")"
current_link="$(basename -- "$(readlink -- "$profile")")"
current_generation="${current_link#"$profile_name"-}"
current_generation="${current_generation%-link}"
cutoff_epoch="$(date --date="$max_age_days days ago" +%s)"

mapfile -t generations < <(
  while IFS= read -r generation_link; do
    generation="${generation_link#"$profile_name"-}"
    generation="${generation%-link}"
    if [[ "$generation" =~ ^[0-9]+$ ]]; then
      printf '%s\n' "$generation"
    fi
  done < <(
    find "$profile_dir" -maxdepth 1 -type l \
      -name "$profile_name-[0-9]*-link" -printf '%f\n'
  )
)

if (( ${#generations[@]} <= keep_generations )); then
  printf 'Keeping all %d generations of %s\n' "${#generations[@]}" "$profile"
  exit 0
fi

mapfile -t generations < <(printf '%s\n' "${generations[@]}" | sort -n)
candidate_count=$((${#generations[@]} - keep_generations))
delete_generations=()

for ((index = 0; index < candidate_count; index++)); do
  generation="${generations[$index]}"
  generation_link="$profile_dir/$profile_name-$generation-link"
  generation_epoch="$(stat --format='%Y' -- "$generation_link")"

  if [[ "$generation" != "$current_generation" ]] && (( generation_epoch <= cutoff_epoch )); then
    delete_generations+=("$generation")
  fi
done

if (( ${#delete_generations[@]} == 0 )); then
  printf 'No generations of %s are both older than %d days and outside the newest %d\n' \
    "$profile" "$max_age_days" "$keep_generations"
  exit 0
fi

printf 'Deleting generations of %s: %s\n' "$profile" "${delete_generations[*]}"

if [[ "${DRY_RUN:-0}" == 1 ]]; then
  exit 0
fi

nix-env --profile "$profile" --delete-generations "${delete_generations[@]}"
