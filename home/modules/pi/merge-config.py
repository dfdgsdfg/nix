#!/usr/bin/env python3
"""Merge managed Pi agent settings and models without overriding runtime state."""

from __future__ import annotations

import argparse
import json
import os
import stat
import sys
import tempfile
from pathlib import Path

SETTINGS_MANAGED = {
    "defaultProvider": "omniroute",
    "defaultModel": "agent/worker",
    "defaultThinkingLevel": "medium",
    "theme": "dark",
}


def write_atomic(path: Path, content: str) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    mode = stat.S_IMODE(path.stat().st_mode) if path.exists() else 0o600
    fd, temporary_name = tempfile.mkstemp(prefix=f".{path.name}.", dir=path.parent)
    try:
        with os.fdopen(fd, "w", encoding="utf-8") as temporary:
            temporary.write(content)
        os.chmod(temporary_name, mode)
        os.replace(temporary_name, path)
    finally:
        if os.path.exists(temporary_name):
            os.unlink(temporary_name)


def load_object(path: Path, label: str) -> dict[str, object]:
    if not path.exists():
        return {}
    try:
        with open(path, "r", encoding="utf-8") as file:
            loaded = json.load(file)
    except json.JSONDecodeError as error:
        raise SystemExit(f"{label} is invalid JSON; refusing to overwrite: {error}") from error
    if not isinstance(loaded, dict):
        raise SystemExit(f"{label} is not a JSON object; refusing to overwrite")
    return loaded


def merge_settings(target_path: Path) -> None:
    existing = load_object(target_path, "settings.json")

    updated = dict(existing)
    updated.update(SETTINGS_MANAGED)

    formatted = json.dumps(updated, indent=2) + "\n"
    if target_path.exists():
        try:
            with open(target_path, "r", encoding="utf-8") as f:
                if f.read() == formatted:
                    return
        except Exception:
            pass

    write_atomic(target_path, formatted)


def merge_models(target_path: Path, source_path: Path) -> None:
    with open(source_path, "r", encoding="utf-8") as f:
        source_data = json.load(f)

    existing = load_object(target_path, "models.json")

    updated = dict(existing)
    providers = updated.get("providers")
    if providers is None:
        providers = {}
        updated["providers"] = providers
    elif not isinstance(providers, dict):
        raise SystemExit("models.json providers is not a JSON object; refusing to overwrite")

    for provider_name, provider_config in source_data.get("providers", {}).items():
        providers[provider_name] = provider_config

    formatted = json.dumps(updated, indent=2) + "\n"
    if target_path.exists():
        try:
            with open(target_path, "r", encoding="utf-8") as f:
                if f.read() == formatted:
                    return
        except Exception:
            pass

    write_atomic(target_path, formatted)


def main() -> None:
    parser = argparse.ArgumentParser(
        description="Merge managed Pi agent settings and models."
    )
    parser.add_argument(
        "--settings",
        type=Path,
        help="Path to ~/.pi/agent/settings.json to merge",
    )
    parser.add_argument(
        "--models",
        type=Path,
        help="Path to ~/.pi/agent/models.json to merge",
    )
    parser.add_argument(
        "--models-source",
        type=Path,
        help="Path to managed source models.json template",
    )

    args = parser.parse_args()

    if args.settings:
        merge_settings(args.settings.expanduser())

    if args.models and args.models_source:
        merge_models(args.models.expanduser(), args.models_source.expanduser())
    elif args.models and not args.models_source:
        sys.exit("Error: --models-source is required when --models is specified.")


if __name__ == "__main__":
    main()
