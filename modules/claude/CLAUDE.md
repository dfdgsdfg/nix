# Subagent routing & cost-efficient reasoning policy

This global policy governs how the Main session delegates work across subagents and
reasoning tiers. Goal: solve each task at the **lowest capability/effort that reliably
works**, escalating only on real difficulty — never merely because a task is large.

## Main session

Main runs at **Opus / high** (pinned via `settings.json`: `model: opus`, `effortLevel: high`).
Main's job is judgment, not grunt work:

- Understand requirements; plan; decompose tasks.
- Make architecture decisions and route work to the right subagent.
- Synthesize subagent results; replan; make final decisions.

Main should **not** personally do broad searches or repetitive implementation — delegate
those. Main handles difficult judgment and independently reviews delegated work; only
exceptional unresolved cases escalate to `powerhouse`. Fast mode is **not** Main's default.

## The agents (model / effort are enforced in each agent's frontmatter)

| Agent          | Model / effort | Use for |
|----------------|----------------|---------|
| `scout`        | Haiku / medium | Fast read-only lookup: specific files, symbols, usages, tests, or one bounded path. |
| `Explore`      | Sonnet / medium | Broad read-only investigation and synthesis; overrides built-in Explore. |
| `general-purpose` | Sonnet / high | Clearly-scoped implementation; overrides built-in general-purpose. |
| `powerhouse`   | Fable / high    | Top-tier exception: architectural/root-cause uncertainty, conflicting agents, repeated failure. |

## Default / unspecified subagents → use the lowest fitting tier

When a task needs a generic subagent and no stronger tier is clearly justified, route narrow
lookups to `scout`, broad investigation to `Explore`, and implementation to `general-purpose`. Do **not**
spin up Opus or Fable for generic exploration/implementation. Prefer a **specialized custom
agent** over a generic/built-in one when a fitting one exists.

`Explore` and `general-purpose` intentionally use the exact built-in names, so their custom
frontmatter enforces Sonnet instead of inheriting Main's Opus model.

## Orchestration rules

- Main concentrates on planning and judgment; delegate execution.
- Route specific files, symbols, usages, tests, or one bounded path to `scout`.
- Route cross-file/cross-subsystem tracing, ambiguous evidence, and synthesis to `Explore`.
- Route clearly-scoped implementation, debugging, and test work to `general-purpose`.
- **Parallelize** independent read-heavy work with the cheapest fitting read-only role.
- Do **not** run write-heavy agents that touch overlapping files concurrently.
- Main independently reviews implementation results and runs or confirms the narrowest meaningful checks.
- **Task size alone never justifies Opus/Fable or higher effort.** Only genuine difficulty does.
- If `general-purpose` fails, Main re-examines the scope, evidence, and decomposition before retrying.
- If repeated failure, conflicting evidence, or architecture/root-cause uncertainty remains → `powerhouse` (Fable/high).

## Escalation ladder (take the lowest rung that works; you may enter directly at the right rung)

```
Haiku / medium         ← narrow lookup and bounded-path scouting
   ↓ broader investigation or synthesis needed
Sonnet / medium        ← broad exploration
   ↓ implementation needed
Sonnet / high          ← general-purpose implementation and self-checking
   ↓ Main review, difficult judgment, or replanning
Opus / high            ← Main
   ↓ repeated failure, conflicting evidence, or fundamental uncertainty
Fable / high           ← powerhouse
   ↓ only when truly exceptional
Fable / xhigh or max   ← per-case, never a default
```

You need not pass through every rung — route directly to the appropriate level for the
task's difficulty, but always prefer the lowest capability/effort that will reliably solve it.

## Fast mode

Fast is orthogonal to the reasoning tier and is **not** a global default. Every role above
runs **Standard** by default. Enable `/fast` only for a specific session or agent when
human-perceived interactive latency is the real bottleneck. Never make Opus/Fable Fast a default.
