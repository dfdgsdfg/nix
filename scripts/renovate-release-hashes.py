#!/usr/bin/env python3
"""Refresh supported fetchurl hashes after Renovate changes a release version.

Input is Renovate's postUpgradeTasks data file, never shell-interpolated metadata.
Source archives and their recursive/dependency hashes remain manual updates.
"""

import json
import os
from pathlib import Path
import re
import subprocess


UPSTREAM = "home/packages/upstream-binaries.nix"
# depName -> (packageFile, pname, optional release-table marker)
PACKAGES = {
    "can1357/oh-my-pi": ("home/modules/omp/default.nix", "omp", "  release ="),
    "stablyai/orca": ("home/modules/desktop/apps.nix", "orca", None),
    "rustdesk/rustdesk": ("home/modules/desktop/apps.nix", "rustdesk", None),
    "xtool-org/xtool": ("home/modules/desktop/dev.nix", "xtool", None),
    "OpenHV/OpenHV": ("home/modules/desktop/games.nix", "openhv", None),
    "herdrdev/herdr": (UPSTREAM, "herdr", None),
    "hashicorp/terraform": (UPSTREAM, "terraform", "  terraformRelease ="),
    "openai/codex": (UPSTREAM, "codex", "  codexRelease ="),
    "block/buzz": (UPSTREAM, "buzz", None),
    "localsend/localsend": (UPSTREAM, "localsend", None),
    "telegramdesktop/tdesktop": (UPSTREAM, "telegram-desktop", None),
    "zackb/tether": (UPSTREAM, "tether", None),
    "zed-industries/zed": (UPSTREAM, "zed-editor", None),
}
HASH = r'hash\s*=\s*"(?P<hash>sha256-[A-Za-z0-9+/]{43}=)";'
URL_HASH = re.compile(r'url\s*=\s*"(?P<url>[^"\n]+)";\s*' + HASH)
RELEASE_HASH = re.compile(
    r'(?P<field>asset|target)\s*=\s*"(?P<value>[^"\n]+)";\s*' + HASH
)


def source_hashes(text, dep, version):
    """Return (hash span, resolved URL) pairs, failing on unexpected layouts."""
    _, pname, table = PACKAGES[dep]
    if not re.fullmatch(r"\d+(?:\.\d+){0,2}", version):
        raise ValueError(f"Unsupported version: {version!r}")
    matches = list(re.finditer(
        r'pname\s*=\s*"' + re.escape(pname) + r'";\s*version\s*=\s*"'
        + re.escape(version) + r'";', text
    ))
    if len(matches) != 1:
        raise ValueError(f"Expected one {pname} at version {version}")
    start = matches[0].end()
    # Limit matching to this package, including Zed's intervening build inputs.
    next_package = re.search(r'\bpname\s*=', text[start:])
    end = start + next_package.start() if next_package else len(text)
    body = text[start:end]
    sources = []
    if table:
        table_start = text.index(table)
        if table_start >= start:
            raise ValueError(f"Release table must precede {pname}")
        releases = list(RELEASE_HASH.finditer(text, table_start, matches[0].start()))
        if len(releases) != 2:
            raise ValueError(f"Expected Linux and Darwin release hashes for {pname}")
        url_match = re.search(r'src\s*=\s*pkgs\.fetchurl\s*\{\s*url\s*=\s*"([^"\n]+)";', body)
        if not url_match:
            raise ValueError(f"Missing fetchurl for {pname}")
        for release in releases:
            # Names used by the three existing platform selectors.
            prefix = {"omp": "release", "codex": "codexRelease", "terraform": "terraformRelease"}[pname]
            url = url_match[1].replace(
                "${" + prefix + "." + release["field"] + "}", release["value"]
            )
            sources.append((release.span("hash"), url))
    else:
        matches = list(URL_HASH.finditer(body))
        expected = 2 if pname == "herdr" else 1
        if len(matches) != expected:
            raise ValueError(f"Expected {expected} source hashes for {pname}, found {len(matches)}")
        for match in matches:
            sources.append(((start + match.start("hash"), start + match.end("hash")), match["url"]))
    resolved = []
    for span, url in sources:
        url = url.replace("${version}", version)
        if "${" in url or not url.startswith("https://"):
            raise ValueError(f"Unsupported source URL: {url}")
        resolved.append((span, url))
    return resolved


def prefetch(url):
    result = subprocess.run(
        ["nix", "store", "prefetch-file", "--json", "--hash-type", "sha256", url],
        check=True, capture_output=True, text=True, timeout=600,
    )
    digest = json.loads(result.stdout)["hash"]
    if not re.fullmatch(r"sha256-[A-Za-z0-9+/]{43}=", digest):
        raise ValueError("Invalid SHA-256 from nix store prefetch-file")
    return digest


def refresh(upgrades, root=Path("."), fetch=prefetch):
    pending = {}
    for upgrade in upgrades:
        dep = upgrade["depName"]
        path, _, _ = PACKAGES[dep]
        if upgrade["packageFile"] != path:
            raise ValueError(f"Unexpected packageFile for {dep}")
        target = root / path
        if target.resolve() != root.resolve() / path:
            raise ValueError(f"Symlinked packageFile: {path}")
        text = pending.get(target, target.read_text())
        changes = [(span, fetch(url)) for span, url in source_hashes(text, dep, upgrade["newValue"])]
        for (start, end), digest in sorted(changes, reverse=True):
            text = text[:start] + digest + text[end:]
        pending[target] = text
        print(f"Refreshed {dep} {upgrade['newValue']}: {len(changes)} source hashes", flush=True)
    # A failed download must not leave only one platform or package updated.
    for target, text in pending.items():
        if target.read_text() != text:
            target.write_text(text)


if __name__ == "__main__":
    data = Path(os.environ["RENOVATE_POST_UPGRADE_COMMAND_DATA_FILE"])
    refresh(json.loads(data.read_text()))
