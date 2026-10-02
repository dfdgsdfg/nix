#!/usr/bin/env python3
"""Public RustDesk server profile and server-qualified connection addresses."""
import argparse
import base64
import json
import pathlib
import shutil
import subprocess
import sys


def config_string(profile):
    # RustDesk 1.4.9 custom_server.rs: reversed URL_SAFE_NO_PAD JSON.
    raw = json.dumps(profile, separators=(",", ":")).encode()
    return base64.urlsafe_b64encode(raw).decode().rstrip("=")[::-1]


def address(peer, profile):
    if not peer or any(c.isspace() or c in "@?&#/" for c in peer):
        raise ValueError("Use a bare RustDesk ID; server and key come from profile.json")
    return f"{peer}@{profile['host']}?key={profile['key']}"


def executable():
    if sys.platform == "darwin":
        app = pathlib.Path("/Applications/RustDesk.app/Contents/MacOS/RustDesk")
        if app.exists():
            return str(app)
    binary = shutil.which("rustdesk") or shutil.which("rustdesk.exe")
    if not binary:
        raise ValueError("RustDesk executable not found; install the native client first")
    return binary


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--directory", type=pathlib.Path, default=pathlib.Path(__file__).parent)
    parser.add_argument("command", choices=["config", "list", "address", "connect"])
    parser.add_argument("peer", nargs="?", help="Registered hostname or bare RustDesk ID")
    args = parser.parse_args()
    profile = json.loads((args.directory / "profile.json").read_text())
    clients = json.loads((args.directory / "clients.json").read_text())
    if args.command == "config":
        print(config_string(profile))
        return
    if args.command == "list":
        for name, peer in clients.items():
            print(f"{name}\t{address(peer, profile) if peer else 'ID pending'}")
        return
    peer = clients.get(args.peer, args.peer)
    if not peer:
        parser.error("RustDesk ID is missing. Set clients.json or pass the device's bare ID.")
    target = address(peer, profile)
    if args.command == "address":
        print(target)
    else:
        subprocess.run([executable(), "--connect", target], check=True)


if __name__ == "__main__":
    try:
        main()
    except (ValueError, subprocess.CalledProcessError) as error:
        sys.exit(str(error))
