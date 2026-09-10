# OmniRoute API agent routing

When using the omni-api profile, use these API-specific agent roles:

- `omni-scout`: narrow read-only lookups, model/gpt-5.3-codex-spark, high effort.
- `omni-explorer`: broader codebase exploration, model/gpt-5.6-terra, medium effort.
- `omni-worker`: bounded implementation and focused tests, model/gpt-5.6-luna, high effort.
- `omni-powerhouse`: independent clean-context re-review, model/gpt-6-astra, xhigh effort.

When repository or shared instructions refer to scout, explorer, worker, or
powerhouse, use the corresponding omni-prefixed role for this profile.
These roles use the omniroute provider and model/ model IDs. Do not select
the unprefixed subscription roles in an omni-api session.

Keep requirements, decomposition, decisions, and final verification in Main.
Complete simple tasks directly. Delegate independent, bounded work only when
it helps; avoid agents editing overlapping files. Keep worker effort at high.
Use omni-powerhouse only for genuine ambiguity, repeated failure, architectural
uncertainty, or conflicting evidence. Verify delegated results independently.
