# Model routing and delegation policy

OMP resolves model roles through `~/.omp/agent/config.yml`. Agent definitions may
select one of those roles explicitly; definitions without a model selector inherit
`@default`. Treat the role names as the stable interface and the underlying model as
replaceable configuration.

## Effective role routes

| OMP role | OmniRoute route | Intended use |
|---|---|---|
| `default` | `model/gpt-6-astra` | Main session, decomposition, integration, acceptance |
| `plan` | `model/gpt-6-astra` | Planning and architecture decisions |
| `task` | `model/gpt-6-luna` | General delegated coding and research |
| `smol` | `model/gpt-6-luna` | Bounded exploration and mechanical work |
| `tiny` | `model/gpt-6-luna` | Lightweight background operations |
| `commit` | `model/gpt-6-luna` | Commit generation and repository work |
| `advisor` | `model/gpt-6-luna` | Independent advice and difficult verification |
| `designer` | `model/payg/gemini-3.8-flash` | UI/UX implementation and review |
| `vision` | `model/payg/gemini-3.5-flash-lite` | Image and document understanding |
| `slow` | `model/gpt-6-astra` | Explicit operator-selected expert escalation |

`~/.omp/agent/config.yml` is authoritative if this table drifts.

The gateway exposes model identities only. OMP roles are client selections;
reasoning effort and service tier belong to the task/session. Model catalogs
expose native effort controls through `thinking` metadata. The default session
uses High. Select Medium or XHigh explicitly for Astra tasks that need it;
`@slow` selects Astra but does not itself change effort. Gemini tasks must also
select their required effort explicitly. GPT-6 Luna keeps Fast service and uses subscription accounts only.
Exhaustion fails visibly; these defaults do not fall back to paid Luna 5.6.

## Main session

The main session runs on `@default` (`model/gpt-6-astra`). Keep it on judgment work:

- Understand requirements and own the top-level decomposition.
- Make architecture and design decisions.
- Define bounded subagent contracts and review their results.
- Integrate changes, verify the outcome, and replan when evidence changes.

Do not use the main session for broad searches or repetitive implementation when a
bounded subagent can perform that work reliably.

## Subagents

Prefer the most specific bundled agent. Respect the model selector in its definition;
do not override it merely because a task is large.

Use the bounded worker/scout paths for delegated work:

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
`model/gpt-6-astra`; this is not the normal route for routine delegated edits.

## Escalation

There is no automatic capability ladder. Task size alone never justifies a stronger
route. If a bounded assignment fails, return the evidence to the main
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
