#!/usr/bin/env python3
"""chezmoi modify_ script for ~/.claude/settings.json on Windows.

Delegates to home/modules/claude/merge-settings.py, which owns only `model` and
`effortLevel` and leaves hooks, statusLine, permissions and session state alone.
Claude Code writes that file itself, so anything less careful than a merge would
throw away state the app depends on.

Its merge() already takes and returns text, so this is a straight pipe.
"""

from __future__ import annotations

import importlib.util
import os
import sys
from pathlib import Path


def load_merge_module() -> object:
    source_dir = os.environ.get("CHEZMOI_SOURCE_DIR")
    if not source_dir:
        sys.exit("CHEZMOI_SOURCE_DIR is unset; run this through chezmoi")

    # windows/chezmoi -> windows -> repo root
    repo_root = Path(source_dir).resolve().parents[1]
    module_path = repo_root / "home" / "modules" / "claude" / "merge-settings.py"
    if not module_path.is_file():
        sys.exit(f"cannot find the managed merge helper at {module_path}")

    spec = importlib.util.spec_from_file_location("claude_merge_settings", module_path)
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


def main() -> None:
    merge = load_merge_module()
    sys.stdout.write(merge.merge(sys.stdin.read()))


if __name__ == "__main__":
    main()
