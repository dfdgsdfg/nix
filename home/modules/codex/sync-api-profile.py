#!/usr/bin/env python3
"""Merge the managed API profile into normal and existing Orca Codex homes."""
import importlib.util
import json
import os
import re
from pathlib import Path
import shutil
import sys
import tempfile
import tomllib

sys.dont_write_bytecode = True

spec = importlib.util.spec_from_file_location('merge_config', sys.argv[2])
merge = importlib.util.module_from_spec(spec)
spec.loader.exec_module(merge)
source = Path(sys.argv[1])
managed = tomllib.loads(source.read_text())


def sections(table, prefix=''):
    values = {k: json.dumps(v) for k, v in table.items() if not isinstance(v, dict)}
    yield prefix, values
    for key, value in table.items():
        if isinstance(value, dict):
            yield from sections(value, prefix+'.'+key if prefix else key)


def remove_legacy_api_roles(text):
    """Remove only old role registrations owned by this API profile."""
    parsed = tomllib.loads(text)
    for name in ('scout', 'explorer', 'worker', 'powerhouse'):
        role = parsed.get('agents', {}).get(name, {})
        path = role.get('config_file', '')
        if not path.endswith(f'/api-agents/{name}.toml'):
            continue
        # Preserve user-defined roles and all unrelated profile sections.
        pattern = rf'(?ms)^\[agents\.{name}\][ \t]*\n.*?(?=^\[|\Z)'
        text = re.sub(pattern, '', text)
    return text


roots = [Path.home()/'.codex']
for parent in [Path.home()/'Library/Application Support/orca/codex-accounts', Path.home()/'.config/orca/codex-accounts', Path.home()/'.config/Orca/codex-accounts']:
    roots.extend(parent.glob('*/home'))
for root in roots:
    target = root/'omni-api.config.toml'
    legacy = root/'api.config.toml'
    # Seed renamed profiles from the previous managed OmniRoute profile only.
    origin = target if target.exists() else None
    if origin is None and legacy.exists():
        previous = tomllib.loads(legacy.read_text())
        if previous.get('model_provider') == 'omniroute':
            origin = legacy
    original = origin.read_text() if origin else ''
    merge.validate(original)
    updated = remove_legacy_api_roles(original)
    for section, values in sections(managed):
        updated = merge.set_section(updated, section, values) if section else merge.set_top_level(updated, values)
    merge.validate(updated)
    if target.exists() and updated == original and not target.is_symlink():
        continue
    root.mkdir(parents=True, exist_ok=True)
    if target.exists() and not target.with_suffix('.toml.before-nix-api').exists():
        shutil.copyfile(target, target.with_suffix('.toml.before-nix-api'))
        target.with_suffix('.toml.before-nix-api').chmod(0o600)
    fd, tmp = tempfile.mkstemp(prefix='.omni-api.config.', dir=root)
    try:
        with os.fdopen(fd, 'w') as f:
            f.write(updated)
        os.chmod(tmp, 0o600)
        os.replace(tmp, target)
    finally:
        if os.path.exists(tmp): os.unlink(tmp)
print('API profiles synchronized without changing default config or login')
