"""Regression check for migrating API roles without altering user settings."""

import runpy
import sys
import tempfile
import tomllib
from pathlib import Path
from unittest.mock import patch


repo = Path(__file__).resolve().parent
with tempfile.TemporaryDirectory() as directory:
    root = Path(directory)
    home = root / '.codex'
    home.mkdir()
    target = home / 'omni-api.config.toml'
    target.write_text('''model = "old"
[agents.worker]
config_file = "/Users/test/.codex/api-agents/worker.toml"
[agents.scout]
config_file = "/custom/scout.toml"
[agents.custom]
config_file = "/custom/worker.toml"
[features]
custom_feature = true
''')
    template = root / 'template.toml'
    template.write_text('''model = "model/gpt-6-astra"
[agents.omni-worker]
config_file = "/Users/test/.codex/api-agents/worker.toml"
''')
    argv = ['sync', str(template), str(repo / 'merge-config.py')]
    with patch.object(Path, 'home', return_value=root), patch.object(sys, 'argv', argv):
        runpy.run_path(str(repo / 'sync-api-profile.py'))
        first = target.read_text()
        parsed = tomllib.loads(first)
        assert 'worker' not in parsed['agents']
        assert 'omni-worker' in parsed['agents']
        assert parsed['agents']['scout']['config_file'] == '/custom/scout.toml'
        assert 'custom' in parsed['agents']
        assert parsed['features']['custom_feature']
        runpy.run_path(str(repo / 'sync-api-profile.py'))
        assert target.read_text() == first
    print('PASS: stale roles removed; user roles/settings preserved; sync idempotent')
