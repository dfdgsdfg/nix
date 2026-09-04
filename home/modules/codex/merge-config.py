#!/usr/bin/env python3
"""Merge the managed Codex defaults without replacing app-managed settings."""

from __future__ import annotations

import os
import re
import stat
import sys
import tomllib
import tempfile
from pathlib import Path


TOP_LEVEL = {
    "model": '"gpt-5.6-sol"',
    "model_reasoning_effort": '"high"',
    "plan_mode_reasoning_effort": '"medium"',
    "check_for_update_on_startup": "false",
}

REMOVE_TOP_LEVEL = ("service_tier",)

SECTIONS = {
    "agents": {
        "enabled": "true",
        "max_concurrent_threads_per_session": "6",
        "default_subagent_model": '"gpt-5.6-luna"',
        "default_subagent_reasoning_effort": '"high"',
    },
    "features": {
        "multi_agent": "true",
        "fast_mode": "true",
    },
}


def set_keys(block: str, values: dict[str, str]) -> str:
    for key, value in values.items():
        pattern = re.compile(rf"(?m)^[ \t]*{re.escape(key)}[ \t]*=.*$")
        replacement = f"{key} = {value}"
        if pattern.search(block):
            block = pattern.sub(replacement, block, count=1)
        else:
            if block and not block.endswith("\n"):
                block += "\n"
            block += replacement + "\n"
    return block


def set_top_level(text: str, values: dict[str, str]) -> str:
    section = re.search(r"(?m)^\s*\[[^\n]+\]\s*$", text)
    split_at = section.start() if section else len(text)
    return set_keys(text[:split_at], values) + text[split_at:]


def remove_top_level(text: str, keys: tuple[str, ...]) -> str:
    section = re.search(r"(?m)^\s*\[[^\n]+\]\s*$", text)
    split_at = section.start() if section else len(text)
    block = text[:split_at]
    for key in keys:
        block = re.sub(rf"(?m)^[ \t]*{re.escape(key)}[ \t]*=.*\n?", "", block)
    return block + text[split_at:]


def set_section(text: str, name: str, values: dict[str, str]) -> str:
    header = re.compile(rf"(?m)^\s*\[{re.escape(name)}\]\s*$")
    match = header.search(text)
    if match is None:
        text = text.rstrip() + f"\n\n[{name}]\n"
        return text + set_keys("", values)

    next_section = re.search(r"(?m)^\s*\[[^\n]+\]\s*$", text[match.end() :])
    end = match.end() + next_section.start() if next_section else len(text)
    return text[: match.end()] + set_keys(text[match.end() : end], values) + text[end:]


def validate(text: str) -> None:
    if not text.strip():
        return
    try:
        parsed = tomllib.loads(text)
    except tomllib.TOMLDecodeError as error:
        raise SystemExit(f"config.toml is invalid TOML; refusing to overwrite: {error}") from error
    if not isinstance(parsed, dict):
        raise SystemExit("config.toml is not a TOML table; refusing to overwrite")


def merge(text: str) -> str:
    validate(text)
    text = remove_top_level(text, REMOVE_TOP_LEVEL)
    text = set_top_level(text, TOP_LEVEL)
    for section, values in SECTIONS.items():
        text = set_section(text, section, values)
    return text.rstrip() + "\n"


def update_file(path: Path) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    original = path.read_text() if path.exists() else ""
    updated = merge(original)
    if updated == original:
        return

    mode = stat.S_IMODE(path.stat().st_mode) if path.exists() else 0o600
    fd, temporary_name = tempfile.mkstemp(prefix=f".{path.name}.", dir=path.parent)
    try:
        with os.fdopen(fd, "w") as temporary:
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
        raise SystemExit(f"usage: {sys.argv[0]} [CONFIG_PATH]")


if __name__ == "__main__":
    main()
