#!/usr/bin/env python3
"""Teach the OmniRoute Pi extension to resolve a command-backed API key.

The extension reads `~/.pi/agent/models.json` itself instead of going through
Pi's credential resolution, then uses that raw value as a bearer token. Our
`providers.omni.apiKey` is command-backed (`!<command>`, the same form Pi
resolves for its own requests), so the extension sends the literal command
string, OmniRoute answers `401 AUTH_002 "Invalid API key"`, and the status bar
reports OmniRoute as down even though inference works.

Upstream 2.0.1 is the latest published version and does not resolve the
prefix. Rather than vendor a fork of the whole extension, rewrite that one
function in the installed copy. The rewrite asserts its anchor: if the
upstream text moves, activation fails loudly instead of reporting a patched
extension that is not patched.
"""

from __future__ import annotations

import argparse
import os
import re
import stat
import sys
import tempfile
from pathlib import Path

# Matches the upstream function regardless of indentation, so a formatting
# change does not silently skip the patch. Captured loosely but rewritten
# whole, so a partial match still produces the full patched function.
UNPATCHED = re.compile(
    r"function getApiKey\(\): string \{\s*"
    r"try \{\s*"
    r"return readModelsJson\(\)\?\.providers\?\.omni\?\.apiKey \|\| \"\";\s*"
    r"\} catch \{\s*"
    r"return \"\";\s*"
    r"\}\s*"
    r"\}",
)

PATCHED = """function getApiKey(): string {
\ttry {
\t\tconst raw = readModelsJson()?.providers?.omni?.apiKey || "";
\t\t// Pi resolves a leading "!" by running the command; do the same here so
\t\t// command-backed credentials work for the extension's own HTTP calls.
\t\tif (raw.startsWith("!")) {
\t\t\tconst { execSync } = require("child_process");
\t\t\treturn execSync(raw.slice(1), { encoding: "utf8", shell: "/bin/sh" }).trim();
\t\t}
\t\treturn raw;
\t} catch {
\t\treturn "";
\t}
}"""

MARKER = 'const { execSync } = require("child_process");'


def write_atomic(path: Path, content: str) -> None:
    mode = stat.S_IMODE(path.stat().st_mode)
    fd, temporary_name = tempfile.mkstemp(prefix=f".{path.name}.", dir=path.parent)
    try:
        with os.fdopen(fd, "w", encoding="utf-8") as temporary:
            temporary.write(content)
        os.chmod(temporary_name, mode)
        os.replace(temporary_name, path)
    finally:
        if os.path.exists(temporary_name):
            os.unlink(temporary_name)


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument(
        "--extension",
        type=Path,
        required=True,
        help="Path to the installed omniroute-pi-ext-integration index.ts",
    )
    arguments = parser.parse_args()
    path = arguments.extension

    # Absent on a host that never installed the extension. Not a failure.
    if not path.exists():
        print(f"omniroute extension not installed at {path}; nothing to patch")
        return

    source = path.read_text(encoding="utf-8")

    if MARKER in source:
        print(f"omniroute extension already resolves command-backed keys: {path}")
        return

    patched, replacements = UNPATCHED.subn(PATCHED, source)
    if replacements != 1:
        raise SystemExit(
            f"Could not patch {path}: expected exactly one getApiKey() definition, "
            f"found {replacements}. Upstream changed its shape; re-review the patch "
            "before editing models.json or removing this activation step."
        )

    write_atomic(path, patched)
    print(f"patched omniroute extension to resolve command-backed API keys: {path}")


if __name__ == "__main__":
    sys.exit(main())
