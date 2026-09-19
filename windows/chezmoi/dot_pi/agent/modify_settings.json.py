#!/usr/bin/env python3
"""chezmoi modify_ script for ~/.pi/agent/settings.json on Windows.

Delegates to home/modules/pi/merge-config.py rather than restating which keys
are managed. Reimplementing SETTINGS_MANAGED here would leave two lists to keep
in step, and the Windows one would quietly rot.

chezmoi hands the file's current contents on stdin and takes the new contents
from stdout, so the merge runs against a staged copy.
"""

from __future__ import annotations

import importlib.util
import os
import sys
import tempfile
from pathlib import Path


def load_merge_module() -> object:
    source_dir = os.environ.get("CHEZMOI_SOURCE_DIR")
    if not source_dir:
        sys.exit("CHEZMOI_SOURCE_DIR is unset; run this through chezmoi")

    # windows/chezmoi -> windows -> repo root
    repo_root = Path(source_dir).resolve().parents[1]
    module_path = repo_root / "home" / "modules" / "pi" / "merge-config.py"
    if not module_path.is_file():
        sys.exit(f"cannot find the managed merge helper at {module_path}")

    spec = importlib.util.spec_from_file_location("pi_merge_config", module_path)
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


def main() -> None:
    merge = load_merge_module()
    current = sys.stdin.read()

    with tempfile.TemporaryDirectory() as tmp:
        staged = Path(tmp) / "settings.json"
        # An absent target arrives as empty stdin. load_object() returns {} for a
        # missing file but rejects an existing empty one as invalid JSON, so
        # leave the staged path uncreated to mean "nothing there yet".
        if current.strip():
            staged.write_text(current, encoding="utf-8")
        merge.merge_settings(staged)
        sys.stdout.write(staged.read_text(encoding="utf-8"))


if __name__ == "__main__":
    main()
