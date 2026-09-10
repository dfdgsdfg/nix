#!/usr/bin/env python3
"""Read the Codex API key from the OS keychain, seeded by a SOPS runtime file."""
import argparse
import os
from pathlib import Path
import stat
import subprocess
import sys

SERVICE = "omniroute-personal-codex"


def run(argv, data=None):
    try:
        return subprocess.run(argv, input=data, capture_output=True, text=True, timeout=20)
    except (OSError, subprocess.TimeoutExpired):
        raise RuntimeError("OS keychain unavailable; unlock your login keychain/Secret Service") from None


def lookup(args):
    if args.platform == "darwin":
        result = run([args.security, "find-generic-password", "-a", args.account, "-s", SERVICE, "-w"])
    else:
        result = run([args.secret_tool, "lookup", "service", "omniroute", "client", "personal-codex"])
    return result.stdout.strip() if result.returncode == 0 else ""


def store(args, token):
    if args.platform == "darwin":
        # security's interactive input keeps the secret out of process arguments.
        def quote(value):
            return '"' + value.replace('\\', '\\\\').replace('"', '\\"') + '"'
        command = "add-generic-password -U -a " + quote(args.account)
        command += " -s " + quote(SERVICE) + " -w " + quote(token) + "\n"
        run([args.security, "-i"], command)
    else:
        run([args.secret_tool, "store", "--label=OmniRoute personal Codex", "service", "omniroute", "client", "personal-codex"], token)
    if lookup(args) != token:
        raise RuntimeError("Cannot store API key; unlock your login keychain/Secret Service")


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--platform", choices=["darwin", "linux"], required=True)
    parser.add_argument("--account", required=True)
    parser.add_argument("--sops-file", type=Path, required=True)
    parser.add_argument("--security", default="/usr/bin/security")
    parser.add_argument("--secret-tool", default="secret-tool")
    args = parser.parse_args()
    try:
        cached = lookup(args)
        if args.sops_file.exists():
            info = args.sops_file.stat()
            if info.st_uid != os.getuid() or stat.S_IMODE(info.st_mode) & 0o077:
                raise RuntimeError("SOPS runtime key must be owned by this user and private")
            token = args.sops_file.read_text().strip()
            if not token or any(c.isspace() or ord(c) < 32 for c in token):
                raise RuntimeError("SOPS runtime key is empty or malformed")
            if cached != token:
                store(args, token)
            cached = token
        if not cached:
            raise RuntimeError("No Codex API key: activate Home Manager with the SOPS age identity, then unlock the OS keychain")
        print(cached)
    except (RuntimeError, OSError):
        print("Codex API authentication failed: activate SOPS secrets and unlock your OS keychain/Secret Service.", file=sys.stderr)
        raise SystemExit(1)


if __name__ == "__main__":
    main()
