#!/usr/bin/env python3
"""Merge the managed Claude Code defaults without replacing app-managed settings."""

from __future__ import annotations

import json
import os
import stat
import sys
import tempfile
from pathlib import Path

MANAGED_SETTINGS: dict[str, object] = {
    "model": "opus",
    "effortLevel": "high",
}


def merge(text: str) -> str:
    if not text.strip():
        data: dict[str, object] = {}
    else:
        try:
            loaded = json.loads(text)
        except json.JSONDecodeError as error:
            raise SystemExit(f"settings.json is invalid JSON; refusing to overwrite: {error}") from error
        if not isinstance(loaded, dict):
            raise SystemExit("settings.json is not a JSON object; refusing to overwrite")
        data = loaded

    for key, value in MANAGED_SETTINGS.items():
        data[key] = value

    return json.dumps(data, indent=2, ensure_ascii=False) + "\n"


def update_file(path: Path) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    original = path.read_text(encoding="utf-8") if path.exists() else ""
    updated = merge(original)
    if updated == original:
        return

    mode = stat.S_IMODE(path.stat().st_mode) if path.exists() else 0o600
    fd, temporary_name = tempfile.mkstemp(prefix=f".{path.name}.", dir=path.parent)
    try:
        with os.fdopen(fd, "w", encoding="utf-8") as temporary:
            temporary.write(updated)
        os.chmod(temporary_name, mode)
        os.replace(temporary_name, path)
    finally:
        if os.path.exists(temporary_name):
            os.unlink(temporary_name)


def main() -> None:
    if len(sys.argv) == 1:
        sys.stdout.write(merge(sys.stdin.read()))
    elif len(sys.argv) == 2:
        update_file(Path(sys.argv[1]).expanduser())
    else:
        raise SystemExit(f"usage: {sys.argv[0]} [SETTINGS_PATH]")


if __name__ == "__main__":
    main()
