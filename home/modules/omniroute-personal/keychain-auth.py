#!/usr/bin/env python3
"""Read an OmniRoute key from OS secure storage, seeded by a SOPS file."""

from __future__ import annotations

import argparse
import os
from pathlib import Path
import stat
import subprocess
import sys


def run(argv: list[str], data: str | None = None) -> subprocess.CompletedProcess[str]:
    try:
        return subprocess.run(argv, input=data, capture_output=True, text=True, timeout=20)
    except (OSError, subprocess.TimeoutExpired):
        raise RuntimeError("OS keychain unavailable; unlock your login keychain/Secret Service") from None


def lookup(args: argparse.Namespace) -> str:
    if args.platform == "darwin":
        result = run(
            [args.security, "find-generic-password", "-a", args.account, "-s", args.service, "-w"]
        )
    else:
        result = run(
            [
                args.secret_tool,
                "lookup",
                "service",
                args.service,
                "client",
                args.client,
            ]
        )
    return result.stdout.strip() if result.returncode == 0 else ""


def store(args: argparse.Namespace, token: str) -> None:
    if args.platform == "darwin":
        # security's interactive input keeps the secret out of process arguments.
        def quote(value: str) -> str:
            return '"' + value.replace("\\", "\\\\").replace('"', '\\"') + '"'

        command = "add-generic-password -U -a " + quote(args.account)
        command += " -s " + quote(args.service) + " -w " + quote(token) + "\n"
        run([args.security, "-i"], command)
    else:
        run(
            [
                args.secret_tool,
                "store",
                f"--label={args.label}",
                "service",
                args.service,
                "client",
                args.client,
            ],
            token,
        )

    if lookup(args) != token:
        raise RuntimeError("Cannot store API key; unlock your login keychain/Secret Service")


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--platform", choices=["darwin", "linux"], required=True)
    parser.add_argument("--account", required=True)
    parser.add_argument("--sops-file", type=Path, required=True)
    parser.add_argument("--service", required=True)
    parser.add_argument("--client", default="personal-pi-omp")
    parser.add_argument("--label", default="OmniRoute personal Pi and OMP")
    parser.add_argument("--security", default="/usr/bin/security")
    parser.add_argument("--secret-tool", default="secret-tool")
    args = parser.parse_args()

    try:
        try:
            cached = lookup(args)
        except (RuntimeError, OSError):
            # An unusable keychain is only fatal if the SOPS seed below cannot
            # supply the key, so record a miss and let that decide.
            cached = ""
        if args.sops_file.exists():
            info = args.sops_file.stat()
            if info.st_uid != os.getuid() or stat.S_IMODE(info.st_mode) & 0o077:
                raise RuntimeError("SOPS runtime key must be owned by this user and private")
            token = args.sops_file.read_text().strip()
            if not token or any(c.isspace() or ord(c) < 32 for c in token):
                raise RuntimeError("SOPS runtime key is empty or malformed")
            if cached != token:
                try:
                    store(args, token)
                except (RuntimeError, OSError):
                    # The keychain only caches the key for when the SOPS runtime
                    # secret is absent. A headless host has no Secret Service to
                    # cache into (WSL reports "The name is not activatable"), but
                    # the seed just read is authoritative, so serve it rather
                    # than failing with a key in hand.
                    pass
            cached = token
        if not cached:
            raise RuntimeError(
                "No OmniRoute API key: activate Home Manager with the SOPS age identity, "
                "then unlock the OS keychain/Secret Service"
            )
        print(cached)
    except (RuntimeError, OSError) as error:
        # Name the underlying cause; the generic advice alone sent debugging
        # toward SOPS when the real fault was a missing Secret Service.
        print(
            "OmniRoute personal API authentication failed; activate SOPS secrets and unlock "
            f"your OS keychain/Secret Service. Cause: {error}",
            file=sys.stderr,
        )
        raise SystemExit(1)


if __name__ == "__main__":
    main()
