#!/usr/bin/env python3
"""chezmoi modify_ script for ~/.pi/agent/models.json on Windows.

Same delegation as modify_settings.json.py: the model catalogue comes from
home/modules/pi/models.json and the merge from home/modules/pi/merge-config.py,
so Windows tracks whatever the nix side declares.

The one Windows-specific rule is the API key. On macOS and NixOS, nix rewrites
providers.omni.apiKey into a `!command` that resolves through the OS keychain.
There is no equivalent wired up here yet, and overwriting a working key with a
command Pi cannot run on Windows would break a host that was fine. So the key
already in the file wins, and bootstrap.ps1 is what seeds it.
"""

from __future__ import annotations

import importlib.util
import json
import os
import sys
import tempfile
from pathlib import Path

PLACEHOLDER = "REPLACE_ME: see windows/README.md"


def repo_root() -> Path:
    source_dir = os.environ.get("CHEZMOI_SOURCE_DIR")
    if not source_dir:
        sys.exit("CHEZMOI_SOURCE_DIR is unset; run this through chezmoi")
    # windows/chezmoi -> windows -> repo root
    return Path(source_dir).resolve().parents[1]


def load_merge_module(root: Path) -> object:
    module_path = root / "home" / "modules" / "pi" / "merge-config.py"
    if not module_path.is_file():
        sys.exit(f"cannot find the managed merge helper at {module_path}")
    spec = importlib.util.spec_from_file_location("pi_merge_config", module_path)
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


def existing_api_key(current: str) -> str | None:
    """Pull providers.omni.apiKey out of the file Pi is using right now."""
    if not current.strip():
        return None
    try:
        data = json.loads(current)
    except json.JSONDecodeError:
        # merge-config.py refuses to overwrite invalid JSON and will say so with
        # a better message; let it be the one to complain.
        return None
    if not isinstance(data, dict):
        return None
    omni = data.get("providers", {}).get("omni", {})
    key = omni.get("apiKey") if isinstance(omni, dict) else None
    return key if isinstance(key, str) and key.strip() else None


def main() -> None:
    root = repo_root()
    merge = load_merge_module(root)
    current = sys.stdin.read()

    managed = json.loads(
        (root / "home" / "modules" / "pi" / "models.json").read_text(encoding="utf-8")
    )
    managed.setdefault("providers", {}).setdefault("omni", {})["apiKey"] = (
        existing_api_key(current) or PLACEHOLDER
    )

    with tempfile.TemporaryDirectory() as tmp:
        staged = Path(tmp) / "models.json"
        source = Path(tmp) / "source.json"
        # See modify_settings.json.py: an empty staged file would be read as
        # invalid JSON, while an absent one correctly means "nothing there yet".
        if current.strip():
            staged.write_text(current, encoding="utf-8")
        source.write_text(json.dumps(managed), encoding="utf-8")
        merge.merge_models(staged, source)
        sys.stdout.write(staged.read_text(encoding="utf-8"))


if __name__ == "__main__":
    main()
