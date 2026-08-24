# Model routing and delegation policy

OMP resolves model roles through `~/.omp/agent/config.yml`. Agent definitions may
select one of those roles explicitly; definitions without a model selector inherit
`@default`. Treat the role names as the stable interface and the underlying model as
replaceable configuration.

## Effective role routes

| OMP role | OmniRoute route | Intended use |
|---|---|---|
| `default` | `agent/orchestrator` | Main session, decomposition, integration, acceptance |
| `plan` | `agent/orchestrator` | Planning and architecture decisions |
| `task` | `agent/worker` | General delegated coding and research |
| `smol` | `agent/cheap` | Bounded exploration and mechanical work |
| `tiny` | `agent/cheap` | Lightweight background operations |
| `commit` | `agent/bulk` | Commit generation and token-heavy repository work |
| `advisor` | `agent/reasoner` | Independent advice and difficult verification |
| `vision` | `agent/multimodal` | Image and document understanding |
| `slow` | `agent/expert` | Explicit operator-selected expert escalation |

`~/.omp/agent/config.yml` is authoritative if this table drifts.

## Main session

The main session runs on `@default` (`agent/orchestrator`). Keep it on judgment work:

- Understand requirements and own the top-level decomposition.
- Make architecture and design decisions.
- Define bounded subagent contracts and review their results.
- Integrate changes, verify the outcome, and replan when evidence changes.

Do not use the main session for broad searches or repetitive implementation when a
bounded subagent can perform that work reliably.

## Subagents

Prefer the most specific bundled agent. Respect the model selector in its definition;
do not override it merely because a task is large.

Use the cheap, non-reasoning path for bounded mechanical work:

- `scout` — read-only codebase exploration and compressed handoff.
- `librarian` — external library and API research from primary sources.
- `sonic` — small mechanical edits.
- `conversation-analyzer` — read-only transcript analysis.
- Generic `task` work only when no more specific agent fits and the assignment is
  narrow and concrete.

Use reasoning-capable specialist agents where a wrong judgment is expensive:

- `reviewer` — independent correctness and regression review.
- `security-reviewer` — evidence-backed security review.
- `designer` — UI/UX implementation and review.

Repository-defined agents without an explicit model selector inherit `@default`.
For example, the homelab `operations` agent currently inherits
`agent/orchestrator`; this is not the normal route for routine delegated edits.

## Escalation

There is no automatic capability ladder. Task size alone never justifies a stronger
route. If a bounded cheap-model assignment fails, return the evidence to the main
session and re-scope it. Use `@advisor` for independent difficult verification and
`@slow` only for explicit operator-selected expert escalation; never silently retry a
failed task on either route.

## Delegation hygiene

- Give each subagent a self-contained brief with goal, constraints, interfaces, and
  exact acceptance criteria; subagents do not inherit the conversation.
- Parallelize genuinely independent read-heavy work.
- Do not run write-heavy subagents concurrently on overlapping files.
- Run review independently of the agent that implemented the change.
- Keep reasoning-heavy decomposition in the main session; cheap agents receive
  narrow tasks whose decisions are already bounded.
