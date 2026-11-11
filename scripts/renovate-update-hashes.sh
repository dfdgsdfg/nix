#!/usr/bin/env bash
# Refresh or verify fixed-output-derivation hashes after Renovate bumped a
# version.
#
# Renovate edits `version = "..."` (and therefore the fetch URLs) in Nix files
# but cannot recompute `hash = "sha256-..."`.
#
# Update mode (default). Run from the repository root with Renovate's edits
# sitting uncommitted in the working tree:
#
#   1. Instantiate the fixed-output derivations (FODs) of every system and Home
#      Manager target for HEAD and for the working tree.
#   2. Keep the working-tree FODs that do not exist at HEAD (their URL changed)
#      and whose stale hash is still written in a tracked *.nix file.
#   3. Prefetch each URL, compute the real hash and rewrite the literal.
#
# Evaluation and prefetching only: nothing is built. Idempotent: a second run
# finds the correct hash already in place and changes nothing.
#
# FODs this mode cannot refresh (fetchCargoVendor, fetchgit, mirror://, custom
# postFetch) are reported, every hash that can be refreshed still is, and the
# script then exits non-zero so a Renovate postUpgradeTask failure surfaces
# instead of leaving a stale hash behind.
#
# Verify mode: `renovate-update-hashes.sh --verify <base-ref>`. Changes nothing.
# Compares the FODs of <base-ref> (a git ref whose tree is read with
# `git archive`) with the working tree, and for each changed FOD whose hash is
# written in a tracked *.nix file makes sure Nix accepts that hash:
#
#   - FODs for a platform this machine can build are realised with `nix build`
#     (only the fetch runs), so Nix itself checks the hash.
#   - FODs for another platform (for example aarch64-darwin on a Linux runner)
#     cannot be built here; plain URL fetches are checked by prefetching and
#     comparing the hash, and anything else fails with an explanation.
#
# Exit status is non-zero when any changed FOD fails verification.
set -euo pipefail

mode=update
base_ref=HEAD
case "${1:-}" in
  "") ;;
  --verify)
    [[ $# -eq 2 && -n "$2" ]] || { printf 'usage: %s [--verify <base-ref>]\n' "$0" >&2; exit 2; }
    mode=verify
    base_ref="$2"
    ;;
  *)
    printf 'usage: %s [--verify <base-ref>]\n' "$0" >&2
    exit 2
    ;;
esac

repo_root="$(git rev-parse --show-toplevel)"
cd "$repo_root"
git rev-parse --verify --quiet "$base_ref^{tree}" >/dev/null \
  || { printf 'error: %s is not a git ref with a tree\n' "$base_ref" >&2; exit 1; }

for tool in nix jq git perl tar; do
  command -v "$tool" >/dev/null || { printf 'error: %s is required\n' "$tool" >&2; exit 1; }
done

work="$(mktemp -d)"
trap 'rm -rf "$work"' EXIT

log() { printf '%s\n' "$*" >&2; }
warn() { printf 'warning: %s\n' "$*" >&2; }
die() { printf 'error: %s\n' "$*" >&2; exit 1; }

# Derivation roots to instantiate for one tree: every Home Manager target, NixOS
# and nix-darwin system (Darwin evaluates fine on Linux), plus the
# upstream-binaries package set for each platform it supports. The latter is
# needed because per-platform releases (terraform, codex, herdr) are not part
# of every closure; OMP's Darwin release is not part of any closure at all.
cat >"$work/roots.nix" <<'EOF'
{ flake }:
let
  self = builtins.getFlake flake;
  lib = self.inputs.nixpkgs.lib;
  strip = builtins.unsafeDiscardStringContext;
  systems = [
    "x86_64-linux"
    "aarch64-darwin"
  ];

  closures =
    lib.mapAttrsToList (_: c: c.activationPackage.drvPath) self.homeConfigurations
    ++ lib.mapAttrsToList (_: c: c.config.system.build.toplevel.drvPath) self.nixosConfigurations
    ++ lib.mapAttrsToList (_: c: c.config.system.build.toplevel.drvPath) self.darwinConfigurations;

  pkgsFor =
    system:
    import self.inputs.nixpkgs-unstable {
      inherit system;
      config.allowUnfree = true;
    };

  upstreamBinaries = lib.concatMap (
    system:
    let
      pkgs = pkgsFor system;
      set = import (self.outPath + "/home/packages/upstream-binaries.nix") { inherit lib pkgs; };
    in
    map (name: set.${name}.drvPath) (
      builtins.filter (name: lib.meta.availableOn pkgs.stdenv.hostPlatform set.${name}) (
        builtins.attrNames set
      )
    )
  ) systems;

  # OMP is not installed on Darwin, so its Darwin release is in no closure.
  # Evaluate the module with Darwin pkgs that claim not to be Darwin so that
  # `home.packages` contains the package, then take its source FOD.
  ompDarwin =
    let
      pkgs = pkgsFor "aarch64-darwin";
      fake = pkgs // {
        stdenv = pkgs.stdenv // {
          hostPlatform = pkgs.stdenv.hostPlatform // {
            isDarwin = false;
          };
        };
      };
      module = import (self.outPath + "/home/modules/omp/default.nix") {
        config = {
          modules.omp.enable = true;
          home.homeDirectory = "/nonexistent";
        };
        inherit lib;
        pkgs = fake;
      };
      result = builtins.tryEval (
        let
          drvs = map (p: p.src.drvPath) module.config.content.home.packages;
        in
        builtins.deepSeq drvs drvs
      );
    in
    if result.success then
      result.value
    else
      builtins.trace "warning: could not evaluate OMP's aarch64-darwin release" [ ];
in
map strip (closures ++ upstreamBinaries ++ ompDarwin)
EOF

# One JSON object per fixed-output derivation in a `nix derivation show -r`
# document (format v4; works for structured and plain attributes).
cat >"$work/fods.jq" <<'EOF'
.derivations | to_entries[]
| select(.value.outputs.out.hash != null)
| .value as $d
| ($d.structuredAttrs // $d.env) as $a
| {
    drv: .key,
    name: $d.name,
    system: $d.system,
    hash: $d.outputs.out.hash,
    method: $d.outputs.out.method,
    urls: (($a.urls // $a.url // "") | if type == "array" then . else split(" ") end | map(select(. != ""))),
    executable: (($a.executable // false) | if type == "string" then . == "1" else . end),
    postFetch: ($a.postFetch // "")
  }
EOF

# collect <flake-ref> <out-prefix>: write <out-prefix>.fods (one FOD per line).
collect() {
  local ref="$1" out="$2" roots=()
  nix eval --json --impure --expr "import $work/roots.nix { flake = \"$ref\"; }" \
    | jq -r '.[]' >"$out.roots"
  mapfile -t roots <"$out.roots"
  [[ ${#roots[@]} -gt 0 ]] || die "no derivation roots found for $ref"
  nix derivation show -r "${roots[@]}" | jq -c -f "$work/fods.jq" >"$out.fods"
}

start=$SECONDS
phase() { log "[$((SECONDS - start))s] $*"; }

# Unchanged files at the base ref, without touching the working tree or needing
# history.
mkdir "$work/head"
git archive "$base_ref" | tar -x -C "$work/head"

phase "instantiating $base_ref and working tree"
collect "path:$work/head" "$work/head" &
head_pid=$!
collect "git+file://$repo_root" "$work/new" &
new_pid=$!
wait "$head_pid" || die "evaluating $base_ref failed"
wait "$new_pid" || die "evaluating the working tree failed"
phase "FODs: $(wc -l <"$work/head.fods" | tr -d ' ') at $base_ref, $(wc -l <"$work/new.fods" | tr -d ' ') in working tree"

# Hash literals currently written in tracked Nix files.
git grep -ohE 'sha256-[A-Za-z0-9+/]{43}=' -- '*.nix' | sort -u >"$work/repo.hashes" || true

# Changed FODs: absent at the base ref, with a hash literal managed in this repository
# (this drops FODs that merely moved with a flake.lock update).
# Update mode keys changes by stale literal (one refresh per hash); verify mode
# checks every changed derivation.
dedupe_key=hash
[[ "$mode" == verify ]] && dedupe_key=drv
jq -r '.drv' "$work/head.fods" | sort -u >"$work/head.drvs"
jq -c -n --rawfile head "$work/head.drvs" --rawfile repo "$work/repo.hashes" '
  ($head | split("\n") | map({(.): true}) | add // {}) as $h
  | ($repo | split("\n") | map({(.): true}) | add // {}) as $r
  | inputs | select(($h[.drv] | not) and $r[.hash])
' "$work/new.fods" | jq -c -s --arg key "$dedupe_key" 'unique_by(.[$key])[]' >"$work/changed.fods"

changed_count="$(wc -l <"$work/changed.fods" | tr -d ' ')"
phase "$changed_count changed FOD(s) with a hash literal in the repository"

# classify <fod-json>: decide whether a FOD is a plain URL fetch that
# `nix store prefetch-file` reproduces. On success sets `fetch_url` and
# `fetch_args`; otherwise returns 1 and sets `skip_reason`.
fetch_url=""
fetch_args=()
skip_reason=""
classify() {
  local fod="$1" method executable post_fetch
  method="$(jq -r '.method' <<<"$fod")"
  executable="$(jq -r '.executable' <<<"$fod")"
  post_fetch="$(jq -r '.postFetch' <<<"$fod")"
  fetch_url="$(jq -r '[.urls[] | select(startswith("mirror://") | not)][0] // empty' <<<"$fod")"
  fetch_args=(--json --hash-type sha256)

  if [[ -z "$fetch_url" ]]; then
    skip_reason="no downloadable URL (cargo vendor, git or mirror://)"
    return 1
  fi
  case "$method" in
    flat)
      if [[ -n "$post_fetch" ]]; then
        skip_reason="flat fetch with a custom postFetch is not supported"
        return 1
      fi
      ;;
    nar)
      if [[ "$post_fetch" == *'unpackFile "$renamed"'* ]]; then
        fetch_args+=(--unpack)
      elif [[ "$executable" == true && -z "$post_fetch" ]]; then
        fetch_args+=(--executable)
      else
        skip_reason="unsupported recursive fetch"
        return 1
      fi
      ;;
    *)
      skip_reason="unsupported hash method '$method'"
      return 1
      ;;
  esac
}

# prefetch_hash: print the SRI hash of `fetch_url` fetched with `fetch_args`.
prefetch_hash() {
  local prefetched hash
  log "prefetching $fetch_url"
  prefetched="$(nix store prefetch-file "${fetch_args[@]}" -- "$fetch_url" </dev/null)" || return 1
  hash="$(jq -r '.hash' <<<"$prefetched")"
  [[ "$hash" == sha256-* ]] || die "unexpected prefetch result: $prefetched"
  printf '%s\n' "$hash"
}

declare -A new_hash_for=()   # stale literal -> refreshed literal
declare -A label_for=()      # stale literal -> FOD name
failures=0
skipped=0

if [[ "$mode" == update ]]; then
  while IFS= read -r fod; do
    old="$(jq -r '.hash' <<<"$fod")"
    name="$(jq -r '.name' <<<"$fod")"

    [[ -z "${new_hash_for[$old]:-}" ]] || continue  # already handled via another root

    if ! classify "$fod"; then
      warn "$name: $skip_reason; update its hash by hand"
      skipped=$((skipped + 1))
      continue
    fi
    if ! new="$(prefetch_hash)"; then
      warn "$name: could not prefetch $fetch_url"
      failures=$((failures + 1))
      continue
    fi

    new_hash_for[$old]="$new"
    label_for[$old]="$name"
  done <"$work/changed.fods"
  phase "prefetched"
fi

if [[ "$mode" == verify ]]; then
  # Systems this machine can build derivations for.
  local_systems=" builtin $(nix eval --raw --impure --expr builtins.currentSystem) $(nix config show extra-platforms || true) "
  store_dir="$(nix eval --raw --impure --expr builtins.storeDir)"
  verified=0
  while IFS= read -r fod; do
    name="$(jq -r '.name' <<<"$fod")"
    drv="$(jq -r '.drv' <<<"$fod")"
    system="$(jq -r '.system' <<<"$fod")"
    declared="$(jq -r '.hash' <<<"$fod")"
    [[ "$drv" == /* ]] || drv="$store_dir/$drv"

    if [[ "$local_systems" == *" $system "* ]]; then
      log "realising $name ($system)"
      if nix build --no-link --print-build-logs "$drv^out" </dev/null; then
        verified=$((verified + 1))
      else
        warn "$name: Nix could not realise the fixed-output derivation; its hash $declared is probably stale ($drv)"
        failures=$((failures + 1))
      fi
      continue
    fi

    # Another platform: only a plain fetch can be checked without building it.
    if ! classify "$fod"; then
      warn "$name: built for $system, which this machine cannot build, and $skip_reason, so its hash $declared could not be verified"
      failures=$((failures + 1))
      continue
    fi
    if ! actual="$(prefetch_hash)"; then
      warn "$name: could not prefetch $fetch_url to verify its hash"
      failures=$((failures + 1))
      continue
    fi
    if [[ "$actual" == "$declared" ]]; then
      log "verified $name ($system) by prefetching: $declared"
      verified=$((verified + 1))
    else
      warn "$name: hash is stale for $fetch_url: declared $declared, actual $actual"
      failures=$((failures + 1))
    fi
  done <"$work/changed.fods"
  phase "verified $verified of $changed_count changed FOD(s)"
  [[ "$failures" -eq 0 ]] || die "$failures changed fixed-output derivation(s) failed verification"
  exit 0
fi

changed=0
for old in "${!new_hash_for[@]}"; do
  new="${new_hash_for[$old]}"
  name="${label_for[$old]}"
  if [[ "$old" == "$new" ]]; then
    log "up to date: $name"
    continue
  fi

  replaced=0
  mapfile -t files < <(git grep -lF -e "$old" -- '*.nix')
  [[ ${#files[@]} -gt 0 ]] || die "$name: $old is no longer present in any tracked file"
  for file in "${files[@]}"; do
    count="$(OLD="$old" perl -0777 -ne 'my $n = () = /\bhash\s*=\s*"\Q$ENV{OLD}\E"/g; print $n' "$file")"
    [[ "$count" -gt 0 ]] || continue
    OLD="$old" NEW="$new" perl -0777 -pi -e 's/(\bhash\s*=\s*")\Q$ENV{OLD}\E(")/$1$ENV{NEW}$2/g' "$file"
    replaced=$((replaced + count))
    printf 'updated %s: %s\n  %s -> %s\n' "$file" "$name" "$old" "$new"
  done
  [[ "$replaced" -gt 0 ]] || die "$name: $old is not inside a hash = \"...\" assignment"
  changed=$((changed + 1))
done

# Surface hash literals that no evaluated FOD refers to: they cannot be
# refreshed automatically (and may be stale).
jq -r '.hash' "$work/new.fods" | sort -u >"$work/new.hashes"
uncovered="$(comm -23 "$work/repo.hashes" "$work/new.hashes" || true)"
if [[ -n "$uncovered" ]]; then
  while IFS= read -r literal; do
    git grep -nF -e "$literal" -- '*.nix' | grep -E 'hash[[:space:]]*=' | while IFS= read -r hit; do
      warn "hash not covered by any evaluated FOD, check by hand: $hit"
    done || true
  done <<<"$uncovered"
fi

phase "done"
if [[ "$changed" -eq 0 ]]; then
  log "no hashes changed"
else
  log "refreshed $changed hash(es)"
fi
[[ "$failures" -eq 0 ]] || die "$failures prefetch(es) failed"
[[ "$skipped" -eq 0 ]] || die "$skipped changed FOD(s) cannot be refreshed automatically; update their hashes by hand"
