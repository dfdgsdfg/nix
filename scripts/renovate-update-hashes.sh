#!/usr/bin/env bash
# Refresh fixed-output-derivation hashes after Renovate bumped a version.
#
# Renovate edits `version = "..."` (and therefore the fetch URLs) in Nix files
# but cannot recompute `hash = "sha256-..."`. Run this from the repository root
# with Renovate's edits sitting uncommitted in the working tree:
#
#   1. Instantiate the fixed-output derivations (FODs) of every system and Home
#      Manager target for HEAD and for the working tree.
#   2. Keep the working-tree FODs that do not exist at HEAD (their URL changed)
#      and whose stale hash is still written in a tracked *.nix file.
#   3. Prefetch each URL, compute the real hash and rewrite the literal.
#
# Evaluation only: nothing is built. Idempotent: a second run finds the correct
# hash already in place and changes nothing.
#
# FODs without a fetchable URL (fetchCargoVendor, fetchgit, mirror://) are
# reported and skipped; the `needs-hash` label covers those by hand.
set -euo pipefail

repo_root="$(git rev-parse --show-toplevel)"
cd "$repo_root"

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

# Unchanged files at HEAD, without touching the working tree or needing history.
mkdir "$work/head"
git archive HEAD | tar -x -C "$work/head"

phase "instantiating HEAD and working tree"
collect "path:$work/head" "$work/head" &
head_pid=$!
collect "git+file://$repo_root" "$work/new" &
new_pid=$!
wait "$head_pid" || die "evaluating HEAD failed"
wait "$new_pid" || die "evaluating the working tree failed"
phase "FODs: $(wc -l <"$work/head.fods" | tr -d ' ') at HEAD, $(wc -l <"$work/new.fods" | tr -d ' ') in working tree"

# Hash literals currently written in tracked Nix files.
git grep -ohE 'sha256-[A-Za-z0-9+/]{43}=' -- '*.nix' | sort -u >"$work/repo.hashes" || true

# Changed FODs: absent at HEAD, with a hash literal managed in this repository
# (this drops FODs that merely moved with a flake.lock update).
jq -r '.drv' "$work/head.fods" | sort -u >"$work/head.drvs"
jq -c -n --rawfile head "$work/head.drvs" --rawfile repo "$work/repo.hashes" '
  ($head | split("\n") | map({(.): true}) | add // {}) as $h
  | ($repo | split("\n") | map({(.): true}) | add // {}) as $r
  | inputs | select(($h[.drv] | not) and $r[.hash])
' "$work/new.fods" | jq -c -s 'unique_by(.hash)[]' >"$work/changed.fods"

changed_count="$(wc -l <"$work/changed.fods" | tr -d ' ')"
phase "$changed_count changed FOD(s) with a hash literal in the repository"

declare -A new_hash_for=()   # stale literal -> refreshed literal
declare -A label_for=()      # stale literal -> FOD name
failures=0

while IFS= read -r fod; do
  old="$(jq -r '.hash' <<<"$fod")"
  name="$(jq -r '.name' <<<"$fod")"
  method="$(jq -r '.method' <<<"$fod")"
  executable="$(jq -r '.executable' <<<"$fod")"
  post_fetch="$(jq -r '.postFetch' <<<"$fod")"
  url="$(jq -r '[.urls[] | select(startswith("mirror://") | not)][0] // empty' <<<"$fod")"

  [[ -z "${new_hash_for[$old]:-}" ]] || continue  # already handled via another root

  if [[ -z "$url" ]]; then
    warn "$name: no downloadable URL (cargo vendor, git or mirror://); update its hash by hand"
    continue
  fi

  args=(--json --hash-type sha256)
  case "$method" in
    flat)
      if [[ -n "$post_fetch" ]]; then
        warn "$name: flat fetch with a custom postFetch is not supported; update its hash by hand"
        continue
      fi
      ;;
    nar)
      if [[ "$post_fetch" == *'unpackFile "$renamed"'* ]]; then
        args+=(--unpack)
      elif [[ "$executable" == true && -z "$post_fetch" ]]; then
        args+=(--executable)
      else
        warn "$name: unsupported recursive fetch; update its hash by hand"
        continue
      fi
      ;;
    *)
      warn "$name: unsupported hash method '$method'; update its hash by hand"
      continue
      ;;
  esac

  log "prefetching $url"
  if ! prefetched="$(nix store prefetch-file "${args[@]}" -- "$url" </dev/null)"; then
    warn "$name: could not prefetch $url"
    failures=$((failures + 1))
    continue
  fi
  new="$(jq -r '.hash' <<<"$prefetched")"
  [[ "$new" == sha256-* ]] || die "$name: unexpected prefetch result: $prefetched"

  new_hash_for[$old]="$new"
  label_for[$old]="$name"
done <"$work/changed.fods"
phase "prefetched"

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
