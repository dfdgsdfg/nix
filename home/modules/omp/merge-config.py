#!/usr/bin/env python3
"""Merge the managed OMP defaults without replacing app-managed or secret settings."""

from __future__ import annotations

import json
import os
import re
import stat
import sys
import tempfile
import yaml
from pathlib import Path

MANAGED_CONFIG_BLOCKS: dict[str, str] = {
    "modelRoles": """modelRoles:
  default: omniroute/agent/orchestrator
  plan: omniroute/agent/orchestrator
  task: omniroute/agent/worker
  designer: omniroute/agent/designer
  advisor: omniroute/agent/worker
  smol: omniroute/agent/worker
  tiny: omniroute/agent/worker
  commit: omniroute/agent/worker
  vision: omniroute/agent/multimodal
  slow: omniroute/agent/expert""",
    "enabledModels": """enabledModels:
  - omniroute/agent/orchestrator
  - omniroute/agent/worker
  - omniroute/agent/scout
  - omniroute/agent/document
  - omniroute/agent/designer
  - omniroute/agent/expert
  - omniroute/agent/multimodal
  - omniroute/model/gpt-5.6-luna
  - omniroute/model/gpt-5.6-sol
  - omniroute/model/gpt-5.3-codex-spark
  - omniroute/model/deepseek-v4-flash-0731
  - omniroute/model/gemini-3.7-flash
  - omniroute/model/gemini-3.5-flash-lite""",
    "defaultThinkingLevel": "defaultThinkingLevel: high",
    "retry": """retry:
  enabled: true
  maxRetries: 1""",
    "task": """task:
  showResolvedModelBadge: true""",
    "setupVersion": "setupVersion: 2",
    "composer": """composer:
  shape: box""",
    "dev": """dev:
  autoqaConsent: denied""",
}

OMNIROUTE_PROVIDER_TEMPLATE = """  omniroute:
    baseUrl: https://omni.tail484abe.ts.net/v1
    api: openai-completions
    authHeader: true
    apiKey: {api_key}
    models:
    - id: agent/orchestrator
      name: Sol orchestrator (High)
      reasoning: true
      thinkingLevelMap:
        off: null
        minimal: null
        low: null
        medium: null
        high: high
        xhigh: null
        max: null
      thinking:
        mode: effort
        efforts: [high]
        defaultLevel: high
        requiresEffort: true
      input:
      - text
      contextWindow: 272000
      maxTokens: 32768
      samplingParams:
        reasoning_effort: high
      compat:
        supportsReasoningEffort: true
        maxTokensField: max_tokens
    - id: agent/worker
      name: Luna worker (High Fast)
      reasoning: true
      thinkingLevelMap:
        off: null
        minimal: null
        low: null
        medium: null
        high: high
        xhigh: null
        max: null
      thinking:
        mode: effort
        efforts: [high]
        defaultLevel: high
        requiresEffort: true
      input:
      - text
      contextWindow: 272000
      maxTokens: 32768
      samplingParams:
        reasoning_effort: high
        service_tier: priority
      compat:
        supportsReasoningEffort: true
        maxTokensField: max_tokens
    - id: agent/scout
      name: GPT-5.3 Codex Spark scout
      reasoning: false
      input:
      - text
      contextWindow: 128000
      maxTokens: 32768
      compat:
        maxTokensField: max_tokens
    - id: agent/document
      name: Gemini 3.7 Flash document specialist (Medium)
      reasoning: true
      thinkingLevelMap:
        off: null
        minimal: null
        low: null
        medium: medium
        high: null
        xhigh: null
        max: null
      thinking:
        mode: effort
        efforts: [medium]
        defaultLevel: medium
        requiresEffort: true
      input:
      - text
      contextWindow: 1048576
      maxTokens: 32768
      samplingParams:
        reasoning_effort: medium
      compat:
        supportsReasoningEffort: true
        maxTokensField: max_tokens
    - id: agent/designer
      name: Gemini 3.7 Flash designer (Medium)
      reasoning: true
      thinkingLevelMap:
        off: null
        minimal: null
        low: null
        medium: medium
        high: null
        xhigh: null
        max: null
      thinking:
        mode: effort
        efforts: [medium]
        defaultLevel: medium
        requiresEffort: true
      input:
      - text
      - image
      contextWindow: 1048576
      maxTokens: 32768
      samplingParams:
        reasoning_effort: medium
      compat:
        supportsReasoningEffort: true
        maxTokensField: max_tokens
    - id: agent/expert
      name: Sol High expert reviewer
      reasoning: true
      thinkingLevelMap:
        off: null
        minimal: null
        low: null
        medium: null
        high: high
        xhigh: null
        max: null
      thinking:
        mode: effort
        efforts: [high]
        defaultLevel: high
        requiresEffort: true
      input:
      - text
      contextWindow: 272000
      maxTokens: 32768
      samplingParams:
        reasoning_effort: high
      compat:
        supportsReasoningEffort: true
        maxTokensField: max_tokens
    - id: agent/multimodal
      name: Gemini Flash-Lite multimodal (Low)
      reasoning: true
      thinkingLevelMap:
        off: null
        minimal: null
        low: low
        medium: null
        high: null
        xhigh: null
        max: null
      thinking:
        mode: effort
        efforts: [low]
        defaultLevel: low
        requiresEffort: true
      input:
      - text
      - image
      contextWindow: 1048576
      maxTokens: 32768
      samplingParams:
        reasoning_effort: low
      compat:
        supportsReasoningEffort: true
        maxTokensField: max_tokens
    - id: model/gpt-5.6-luna
      name: GPT-5.6 Luna identity
      reasoning: true
      thinkingLevelMap:
        off: none
        minimal: null
        low: low
        medium: medium
        high: high
        xhigh: xhigh
        max: max
      thinking:
        mode: effort
        efforts: [low, medium, high, xhigh, max]
      input:
      - text
      contextWindow: 272000
      maxTokens: 32768
      compat:
        supportsReasoningEffort: true
        maxTokensField: max_tokens
    - id: model/gpt-5.6-sol
      name: GPT-5.6 Sol identity
      reasoning: true
      thinkingLevelMap:
        off: none
        minimal: null
        low: low
        medium: medium
        high: high
        xhigh: xhigh
        max: max
      thinking:
        mode: effort
        efforts: [low, medium, high, xhigh, max]
      input:
      - text
      contextWindow: 272000
      maxTokens: 32768
      compat:
        supportsReasoningEffort: true
        maxTokensField: max_tokens
    - id: model/gpt-5.3-codex-spark
      name: GPT-5.3 Codex Spark identity
      reasoning: false
      input:
      - text
      contextWindow: 128000
      maxTokens: 32768
      compat:
        maxTokensField: max_tokens
    - id: model/deepseek-v4-flash-0731
      name: DeepSeek V4 Flash 0731 identity
      reasoning: true
      thinkingLevelMap:
        off: none
        minimal: null
        low: low
        medium: null
        high: high
        xhigh: null
        max: max
      thinking:
        mode: effort
        efforts: [low, high, max]
      input:
      - text
      contextWindow: 1000000
      maxTokens: 32768
      compat:
        supportsReasoningEffort: true
        thinkingFormat: openai
        requiresReasoningContentOnAssistantMessages: true
        maxTokensField: max_tokens
    - id: model/gemini-3.7-flash
      name: Gemini 3.7 Flash identity
      reasoning: true
      thinkingLevelMap:
        off: null
        minimal: null
        low: low
        medium: medium
        high: high
        xhigh: null
        max: null
      thinking:
        mode: effort
        efforts: [low, medium, high]
        requiresEffort: true
      input:
      - text
      - image
      contextWindow: 1048576
      maxTokens: 32768
      compat:
        supportsReasoningEffort: true
        maxTokensField: max_tokens
    - id: model/gemini-3.5-flash-lite
      name: Gemini 3.5 Flash-Lite identity
      reasoning: true
      thinkingLevelMap:
        off: null
        minimal: minimal
        low: low
        medium: medium
        high: high
        xhigh: null
        max: null
      thinking:
        mode: effort
        efforts: [minimal, low, medium, high]
        requiresEffort: true
      input:
      - text
      - image
      contextWindow: 1048576
      maxTokens: 32768
      compat:
        supportsReasoningEffort: true
        maxTokensField: max_tokens"""


def split_yaml_top_level_blocks(text: str) -> list[tuple[str | None, str]]:
    blocks: list[tuple[str | None, str]] = []
    key_pattern = re.compile(r"^(?P<key>[A-Za-z0-9_-]+)\s*:", re.MULTILINE)
    matches = list(key_pattern.finditer(text))

    if not matches:
        if text.strip():
            blocks.append((None, text))
        return blocks

    if matches[0].start() > 0:
        prefix = text[: matches[0].start()]
        if prefix.strip():
            blocks.append((None, prefix))

    for i, match in enumerate(matches):
        key = match.group("key")
        start = match.start()
        end = matches[i + 1].start() if i + 1 < len(matches) else len(text)
        block = text[start:end]
        blocks.append((key, block.rstrip()))

    return blocks


def merge_config(original: str) -> str:
    blocks = split_yaml_top_level_blocks(original)
    existing_keys: set[str] = set()
    result_blocks: list[str] = []

    for key, block in blocks:
        if key is None:
            result_blocks.append(block)
        elif key in MANAGED_CONFIG_BLOCKS:
            existing_keys.add(key)
            result_blocks.append(MANAGED_CONFIG_BLOCKS[key])
        else:
            result_blocks.append(block)

    for key, block in MANAGED_CONFIG_BLOCKS.items():
        if key not in existing_keys:
            result_blocks.append(block)

    return "\n".join(b for b in result_blocks if b.strip()) + "\n"


def extract_existing_api_key(text: str, provider: str = "omniroute") -> str | None:
    p_pattern = re.compile(rf"^\s*{re.escape(provider)}\s*:", re.MULTILINE)
    m = p_pattern.search(text)
    if not m:
        return None
    rest = text[m.end() :]
    next_p = re.search(r"^  [A-Za-z0-9_-]+\s*:", rest, re.MULTILINE)
    section = rest[: next_p.start()] if next_p else rest
    key_match = re.search(r"^\s*apiKey\s*:\s*['\"]?([^'\"\n]+)['\"]?\s*$", section, re.MULTILINE)
    if key_match:
        return key_match.group(1).strip()
    return None


def resolve_api_key(existing_text: str, provider: str = "omniroute") -> str:
    del existing_text, provider
    command = os.environ.get(
        "OMP_API_KEY_COMMAND",
        '!security find-generic-password -a "$USER" -s "omniroute-us-mbp-omp" -w',
    )
    return json.dumps(command)


def merge_models(original: str) -> str:
    api_key = resolve_api_key(original, "omniroute")
    provider_block = OMNIROUTE_PROVIDER_TEMPLATE.format(api_key=api_key)

    if not original.strip():
        return f"providers:\n{provider_block}\n"

    p_header = re.search(r"^providers\s*:", original, re.MULTILINE)
    if not p_header:
        return original.rstrip() + f"\n\nproviders:\n{provider_block}\n"

    start_providers = p_header.end()
    next_top = re.search(r"^[A-Za-z0-9_-]+\s*:", original[start_providers:], re.MULTILINE)
    end_providers = start_providers + next_top.start() if next_top else len(original)

    providers_text = original[start_providers:end_providers]

    omni_match = re.search(r"^  omniroute\s*:", providers_text, re.MULTILINE)
    if omni_match:
        rest = providers_text[omni_match.start() :]
        next_prov = re.search(r"\n  [A-Za-z0-9_-]+\s*:", rest[1:])
        if next_prov:
            omni_end = omni_match.start() + 1 + next_prov.start()
        else:
            omni_end = len(providers_text)

        new_providers_text = (
            providers_text[: omni_match.start()] + "\n" + provider_block + providers_text[omni_end:]
        )
    else:
        new_providers_text = providers_text.rstrip() + "\n" + provider_block + "\n"

    return original[:start_providers] + new_providers_text + original[end_providers:]


def validate_yaml(text: str, label: str) -> None:
    if not text.strip():
        return
    try:
        loaded = yaml.safe_load(text)
    except yaml.YAMLError as error:
        raise SystemExit(f"{label} is invalid YAML; refusing to overwrite: {error}") from error
    if not isinstance(loaded, dict):
        raise SystemExit(f"{label} is not a YAML mapping; refusing to overwrite")


def update_file(path: Path, merge_fn) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    original = path.read_text() if path.exists() else ""
    validate_yaml(original, path.name)
    updated = merge_fn(original)
    if updated == original:
        return

    mode = stat.S_IMODE(path.stat().st_mode) if path.exists() else 0o600
    fd, temporary_name = tempfile.mkstemp(prefix=f".{path.name}.", dir=path.parent)
    try:
        with os.fdopen(fd, "w") as temporary:
            temporary.write(updated)
        os.chmod(temporary_name, mode)
        os.replace(temporary_name, path)
    finally:
        if os.path.exists(temporary_name):
            os.unlink(temporary_name)


def main() -> None:
    if len(sys.argv) == 1:
        sys.stdout.write(merge_config(sys.stdin.read()))
    elif len(sys.argv) == 2:
        target = Path(sys.argv[1]).expanduser()
        if target.is_dir() or target.name not in ("config.yml", "models.yml"):
            config_path = target / "config.yml"
            models_path = target / "models.yml"
            validate_yaml(config_path.read_text() if config_path.exists() else "", config_path.name)
            validate_yaml(models_path.read_text() if models_path.exists() else "", models_path.name)
            update_file(config_path, merge_config)
            update_file(models_path, merge_models)
        elif target.name == "config.yml":
            update_file(target, merge_config)
        else:
            update_file(target, merge_models)
    elif len(sys.argv) == 3:
        update_file(Path(sys.argv[1]).expanduser(), merge_config)
        update_file(Path(sys.argv[2]).expanduser(), merge_models)
    else:
        raise SystemExit(f"usage: {sys.argv[0]} [CONFIG_PATH_OR_DIR] [MODELS_PATH]")


if __name__ == "__main__":
    main()
