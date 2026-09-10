#!/usr/bin/env python3
"""Adapt installed Codex model metadata to OmniRoute's five public model IDs."""
import json
import os
from pathlib import Path
import subprocess
import sys

MODELS = ['gpt-6-astra', 'gpt-5.6-sol', 'gpt-5.6-terra', 'gpt-5.6-luna', 'gpt-5.3-codex-spark']


def build(codex):
    data = json.loads(subprocess.run([codex, 'debug', 'models', '--bundled'], capture_output=True, text=True, check=True).stdout)
    models = {m['slug']: m for m in data['models']}
    roots = [Path.home()/'.codex']
    if os.environ.get('CODEX_HOME'):
        roots.append(Path(os.environ['CODEX_HOME']))
    roots.extend((Path.home()/'Library/Application Support/orca/codex-accounts').glob('*/home'))
    for root in roots:
        try:
            cached = json.loads((root/'models_cache.json').read_text())
            for model in cached.get('models', []):
                if model.get('slug') == 'gpt-5.3-codex-spark':
                    models[model['slug']] = model
        except (OSError, ValueError, TypeError):
            continue
    if MODELS[-1] not in models:
        # Spark may be absent from the bundled API catalog. Keep conservative
        # text-only metadata until a subscription catalog supplies its entry.
        spark = dict(models['gpt-5.6-luna'])
        spark.update(slug=MODELS[-1], display_name='GPT-5.3 Codex Spark', context_window=128000, description='Codex Spark subscription model')
        models[MODELS[-1]] = spark
    result = []
    for name in MODELS:
        model = dict(models[name])
        model.update(slug='model/'+name, supported_in_api=True, visibility='list')
        result.append(model)
    return {'models': result}


if __name__ == '__main__':
    target = Path(sys.argv[2]); target.parent.mkdir(parents=True, exist_ok=True)
    result = build(sys.argv[1])
    temporary = target.with_name(target.name+'.tmp')
    temporary.write_text(json.dumps(result, indent=2)+'\n')
    temporary.chmod(0o600)
    temporary.replace(target)
