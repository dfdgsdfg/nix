"""Merge bookmarks without changing UUIDs (keyring identities) or UI preferences."""

import configparser
import io
import json
import os
from pathlib import Path
import shutil
import sys
import tempfile
import uuid


def merge(path, targets):
    db = configparser.ConfigParser(interpolation=None)
    db.optionxform = str
    original = path.read_text() if path.exists() else ""
    db.read_string(original)
    changed = False
    for name, target in targets.items():
        host = target["host"]
        authority = f"[{host}]" if ":" in host else host
        uri = f'{target["protocol"]}://{authority}:{target["port"]}'
        identity = str(uuid.uuid5(uuid.NAMESPACE_URL, f"nix:gnome-connections:{name}"))
        # Adopt existing bookmarks so their saved credentials remain associated.
        section = next((s for s in db.sections() if db[s].get("uri") == uri), None)
        section = section or (identity if db.has_section(identity) else None)
        section = section or next((s for s in db.sections()
                                  if db[s].get("display-name") == target["displayName"]), identity)
        if not db.has_section(section):
            db.add_section(section)
        for key, value in {"protocol": target["protocol"], "host": host,
                           "uri": uri, "display-name": target["displayName"]}.items():
            if db[section].get(key) != value:
                db[section][key] = value
                changed = True
    if not changed:
        return
    output = io.StringIO()
    db.write(output, space_around_delimiters=False)
    path.parent.mkdir(parents=True, exist_ok=True)
    if path.exists():
        backup = path.with_name(path.name + ".before-nix")
        if not backup.exists():
            shutil.copy2(path, backup)
    fd, temporary = tempfile.mkstemp(prefix=".connections-", dir=path.parent)
    try:
        with os.fdopen(fd, "w") as stream:
            stream.write(output.getvalue())
        os.replace(temporary, path)
    finally:
        if os.path.exists(temporary):
            os.unlink(temporary)


if __name__ == "__main__":
    merge(Path(sys.argv[1]), json.loads(Path(sys.argv[2]).read_text()))
