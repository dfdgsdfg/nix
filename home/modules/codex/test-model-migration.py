"""Check client model migration without losing native controls or user state."""
import importlib.util
import json
from pathlib import Path
import tomllib
import yaml

ROOT = Path(__file__).resolve().parents[3]


def module(name, path):
    spec = importlib.util.spec_from_file_location(name, ROOT / path)
    result = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(result)
    return result


codex = module('codex_merge', 'home/modules/codex/merge-config.py')
omp = module('omp_merge', 'home/modules/omp/merge-config.py')
pi = module('pi_merge', 'home/modules/pi/merge-config.py')
source = '''model = "gpt-5.6-sol"
prompt = """
model = "gpt-5.6-luna"
"""
[agents]
default_subagent_model = 'model/gpt-5.6-luna' # keep comment
[profiles.custom]
model = "gpt-5.6-terra"
api_key = "gpt-5.6-luna"
'''
updated = codex.migrate_model_selections(source)
parsed = tomllib.loads(updated)
assert parsed['model'] == 'gpt-6-sol'
assert 'model = "gpt-5.6-luna"' in parsed['prompt']
assert parsed['agents']['default_subagent_model'] == 'model/gpt-6-luna'
assert parsed['profiles']['custom']['model'] == 'gpt-6-sol'
assert parsed['profiles']['custom']['api_key'] == 'gpt-5.6-luna'
assert '# keep comment' in updated
assert codex.migrate_model_selections(updated) == updated
for old, new in [('model/gpt-5.6-sol', 'model/gpt-6-sol'),
                 ('model/gpt-5.6-terra', 'model/gpt-6-sol'),
                 ('model/gpt-5.6-luna', 'model/gpt-6-luna'),
                 ('model/payg-fb/gpt-5.6-luna', 'model/gpt-6-luna')]:
    result = omp.merge_config('model: omniroute/' + old + '\ncustom: keep\n')
    assert yaml.safe_load(result)['model'] == 'omniroute/' + new
    assert yaml.safe_load(result)['custom'] == 'keep'
    assert omp.merge_config(result) == result
catalogs = [json.loads((ROOT / 'home/modules/pi/models.json').read_text())['providers']['omni']['models'],
            yaml.safe_load(omp.merge_models(''))['providers']['omniroute']['models']]
for models in catalogs:
    assert not any('gpt-5.6' in m['id'] for m in models)
    assert len({m['id'] for m in models}) == len(models)
    luna = next(m for m in models if m['id'] == 'model/gpt-6-luna')
    assert luna['samplingParams']['service_tier'] == 'priority'
    assert luna['contextWindow'] == 272000
assert pi.SETTINGS_MANAGED['defaultModel'] == 'model/gpt-6-luna'
assert pi.SETTINGS_MANAGED['defaultThinkingLevel'] == 'high'
print('PASS: GPT-6 selections, saved models, prompts/credentials, tier, and idempotence')
