#!/usr/bin/env python3
import argparse
import json
import os
import shutil
import sys
from datetime import datetime
from pathlib import Path


def default_heroic_config() -> Path:
    return Path.home() / ".config" / "heroic" / "store" / "config.json"


def default_gog_library() -> Path:
    return Path.home() / ".config" / "heroic" / "store_cache" / "gog_library.json"


def load_json(path: Path) -> object:
    try:
        with path.open("r", encoding="utf-8") as f:
            return json.load(f)
    except FileNotFoundError:
        raise SystemExit(f"Missing file: {path}")
    except json.JSONDecodeError as exc:
        raise SystemExit(f"Invalid JSON in {path}: {exc}")


def write_json(path: Path, data: object) -> None:
    tmp_path = path.with_suffix(path.suffix + ".tmp")
    with tmp_path.open("w", encoding="utf-8") as f:
        json.dump(data, f, indent=2, ensure_ascii=False)
        f.write("\n")
    tmp_path.replace(path)


def heroic_is_running() -> bool:
    proc = Path("/proc")
    if not proc.exists():
        return False

    current_pid = os.getpid()
    for entry in proc.iterdir():
        if not entry.name.isdigit():
            continue

        pid = int(entry.name)
        if pid == current_pid:
            continue

        try:
            cmdline = (entry / "cmdline").read_bytes().replace(b"\x00", b" ").decode(
                "utf-8",
                errors="ignore",
            )
        except OSError:
            continue

        command = cmdline.lower()
        if not command:
            continue

        if "heroic-sync-gog-genres" in command:
            continue

        if "/heroic" in command or "heroic games launcher" in command:
            return True

    return False


def normalize_categories(value: object) -> dict[str, list[str]]:
    if value is None:
        return {}
    if not isinstance(value, dict):
        raise SystemExit("games.customCategories exists, but is not an object")

    categories: dict[str, list[str]] = {}
    for key, games in value.items():
        if not isinstance(key, str):
            continue
        if not isinstance(games, list):
            categories[key] = []
            continue
        categories[key] = [game for game in games if isinstance(game, str)]

    return categories


def collect_gog_genres(
    library: object,
    prefix: str,
) -> tuple[dict[str, set[str]], dict[str, set[str]], int, int]:
    if not isinstance(library, dict) or not isinstance(library.get("games"), list):
        raise SystemExit("GOG library cache must contain a games array")

    categories: dict[str, set[str]] = {}
    legacy_categories: dict[str, set[str]] = {}
    games_seen = 0
    games_with_genres = 0

    for game in library["games"]:
        if not isinstance(game, dict):
            continue

        app_name = game.get("app_name")
        if not isinstance(app_name, str) or app_name == "gog-redist":
            continue

        runner = game.get("runner")
        if not isinstance(runner, str) or not runner:
            runner = "gog"
        heroic_game_id = f"{app_name}_{runner}"

        games_seen += 1

        extra = game.get("extra")
        genres = extra.get("genres") if isinstance(extra, dict) else None
        if not isinstance(genres, list):
            genres = game.get("genres")
        if not isinstance(genres, list):
            continue

        added_for_game = False
        for genre in genres:
            if not isinstance(genre, str):
                continue
            genre_name = genre.strip()
            if not genre_name:
                continue
            category = prefix + genre_name
            categories.setdefault(category, set()).add(heroic_game_id)
            legacy_categories.setdefault(category, set()).add(app_name)
            added_for_game = True

        if added_for_game:
            games_with_genres += 1

    return categories, legacy_categories, games_seen, games_with_genres


def merge_categories(
    existing: dict[str, list[str]],
    generated: dict[str, set[str]],
    legacy_generated: dict[str, set[str]],
) -> tuple[dict[str, list[str]], int, int]:
    merged = {key: list(value) for key, value in existing.items()}
    additions = 0
    legacy_removals = 0

    for category, app_names in sorted(generated.items()):
        current = set(merged.get(category, []))
        legacy_app_names = legacy_generated.get(category, set())
        legacy_removals += len(current.intersection(legacy_app_names))
        current.difference_update(legacy_app_names)
        before = len(current)
        current.update(app_names)
        additions += len(current) - before
        merged[category] = sorted(current)

    return merged, additions, legacy_removals


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description="Merge GOG genre metadata from Heroic's cache into Heroic custom categories.",
    )
    parser.add_argument(
        "--config",
        type=Path,
        default=default_heroic_config(),
        help="Heroic store config path",
    )
    parser.add_argument(
        "--library",
        type=Path,
        default=default_gog_library(),
        help="Heroic GOG library cache path",
    )
    parser.add_argument(
        "--prefix",
        default="",
        help='Prefix generated categories, for example "GOG: "',
    )
    parser.add_argument(
        "--dry-run",
        action="store_true",
        help="Print a summary without writing config changes",
    )
    parser.add_argument(
        "--force",
        action="store_true",
        help="Write even if Heroic appears to be running",
    )
    parser.add_argument(
        "--no-backup",
        action="store_true",
        help="Do not create a timestamped backup before writing",
    )
    return parser.parse_args()


def main() -> int:
    args = parse_args()

    config_path = args.config.expanduser()
    library_path = args.library.expanduser()

    config = load_json(config_path)
    library = load_json(library_path)

    if not isinstance(config, dict):
        raise SystemExit("Heroic config must be a JSON object")

    generated, legacy_generated, games_seen, games_with_genres = collect_gog_genres(
        library,
        args.prefix,
    )

    games = config.setdefault("games", {})
    if not isinstance(games, dict):
        raise SystemExit("Heroic config field 'games' exists, but is not an object")

    existing = normalize_categories(games.get("customCategories"))
    merged, additions, legacy_removals = merge_categories(
        existing,
        generated,
        legacy_generated,
    )

    print(f"GOG games scanned: {games_seen}")
    print(f"GOG games with genres: {games_with_genres}")
    print(f"Genre categories found: {len(generated)}")
    print(f"New game/category links: {additions}")
    print(f"Legacy raw links replaced: {legacy_removals}")

    if args.dry_run:
        print("Dry run only; no files changed.")
        return 0

    if heroic_is_running() and not args.force:
        print(
            "Heroic appears to be running. Close Heroic first, or rerun with --force.",
            file=sys.stderr,
        )
        return 2

    if additions == 0 and games.get("customCategories") == merged:
        print("Nothing to change.")
        return 0

    if not args.no_backup:
        stamp = datetime.now().strftime("%Y%m%d-%H%M%S")
        backup_path = config_path.with_name(f"{config_path.name}.bak-{stamp}")
        shutil.copy2(config_path, backup_path)
        print(f"Backup written: {backup_path}")

    games["customCategories"] = merged
    write_json(config_path, config)
    print(f"Updated: {config_path}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
