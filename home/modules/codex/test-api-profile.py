"""Regression check for migrating API roles without altering user settings."""

import runpy
import json
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
    native = home / 'config.toml'
    native.write_text('[features]\nmulti_agent = true\ncustom_feature = true\n')
    legacy_api = home / 'api.config.toml'
    legacy_api.write_text('[features]\nmulti_agent = false\n')
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
multi_agent = true
''')
    template = root / 'template.toml'
    instructions = 'First line\nSecond line with "quotes" and C:\\tools\\new'
    template.write_text('developer_instructions = ' + json.dumps(instructions) + '\n' + '''model = "model/gpt-6.2-sol"
[agents.omni-worker]
config_file = "/Users/test/.codex/api-agents/worker.toml"
''')
    orca = root / 'Library/Application Support/orca/codex-accounts/test/home'
    orca.mkdir(parents=True)
    (orca / 'config.toml').write_text('model = "gpt-6.1-sol"\nmodel_context_window = 500000\nmodel_reasoning_effort = "medium"\nservice_tier = "priority"\nprompt = "gpt-6.1-sol"\n')
    (orca / 'api.config.toml').write_text('model = "model/gpt-6-astra"\nmodel_context_window = 128000\nmodel_reasoning_effort = "xhigh"\n')
    argv = ['sync', str(template), str(repo / 'merge-config.py')]
    with patch.object(Path, 'home', return_value=root), patch.object(sys, 'argv', argv):
        runpy.run_path(str(repo / 'sync-api-profile.py'))
        first = target.read_text()
        parsed = tomllib.loads(first)
        assert parsed['developer_instructions'] == instructions
        assert 'worker' not in parsed['agents']
        assert 'omni-worker' in parsed['agents']
        assert parsed['agents']['scout']['config_file'] == '/custom/scout.toml'
        assert 'custom' in parsed['agents']
        assert parsed['features']['custom_feature']
        assert 'multi_agent' not in parsed['features']
        assert parsed['agents']['enabled'] is True
        assert tomllib.loads(native.read_text()) == {
            'features': {'custom_feature': True}, 'agents': {'enabled': True}}
        assert tomllib.loads(legacy_api.read_text()) == {
            'features': {}, 'agents': {'enabled': False}}
        current = tomllib.loads((orca / 'config.toml').read_text())
        assert current == {'model': 'gpt-6.2-sol', 'model_context_window': 272000,
                           'model_reasoning_effort': 'medium', 'service_tier': 'priority',
                           'prompt': 'gpt-6.1-sol'}
        api = tomllib.loads((orca / 'api.config.toml').read_text())
        assert api == {'model': 'model/gpt-6.2-astra', 'model_context_window': 128000,
                       'model_reasoning_effort': 'xhigh'}
        assert (orca / 'config.toml.before-gpt62').stat().st_mode & 0o777 == 0o600
        runpy.run_path(str(repo / 'sync-api-profile.py'))
        assert target.read_text() == first
    print('PASS: stale roles removed; user roles/settings preserved; sync idempotent')
