# Model routing and delegation policy

OMP resolves model roles through `~/.omp/agent/config.yml`. Roles select models;
agent definitions supply task instructions and tools. A role alone does not
create an agent. Definitions without a model selector inherit the parent's
active model before falling back to its configured/default model.

## Effective role routes

| OMP role | OmniRoute route | Effort | Intended use |
|---|---|---|---|
| `default` | `model/gpt-6-astra` | medium | Main session, decomposition, integration, acceptance |
| `plan` | `model/gpt-6-astra` | high | Planning and architecture decisions |
| `task` | `model/gpt-6-luna` | high | Bounded implementation and focused tests |
| `explore` | `model/gpt-6-sol` | medium | Relationships across modules and failure analysis |
| `smol` | `model/gpt-6-luna` | medium | Narrow exploration and mechanical work |
| `tiny` | `model/gpt-6-luna` | session/default | Lightweight background operations |
| `commit` | `model/gpt-6-luna` | session/default | Commit generation and repository work |
| `advisor` | `model/gpt-6-luna` | session/default | Optional ongoing assistance, not final acceptance |
| `designer` | `model/payg/gemini-3.8-flash` | explicit selection | UI/UX model role; no dedicated agent installed |
| `vision` | `model/payg/gemini-3.5-flash-lite` | explicit selection | Image and document understanding |
| `slow` | `model/gpt-6-astra` | high | Independent correctness and security review |

`~/.omp/agent/config.yml` is authoritative if this table drifts. Role selectors
include effort suffixes where listed; the default thinking level is medium.
Explicit session or task effort settings may override these defaults. Use xhigh
for a consequential, unresolved question when the evidence warrants it, not
merely because the assignment is large.

The gateway exposes model identities. Role selection and reasoning effort are
client settings. GPT-6 Luna keeps Fast service and uses subscription accounts
only. Exhaustion fails visibly; these defaults do not fall back to paid Luna 5.6.

## Main session

Keep the main session on judgment work: understand requirements, define bounded
assignments and acceptance criteria, make architectural decisions, integrate
changes, and independently verify the result. Complete small tasks directly.
Delegate substantial work when a bounded assignment can reduce search or
implementation effort without losing necessary context.

## Available agents

The managed user definitions are `scout` and `explorer`. The remaining agents
below are bundled with OMP 18.3.1.

- `scout` — Luna/medium via `@smol`. Locate files, symbols, ownership, or one
  bounded execution path. Read-only; return uncertainty to the parent.
- `explorer` — Sol/medium via `@explore`. Trace relationships across modules,
  compare plausible causes, and produce an implementation handoff. Read-only;
  return architectural decisions to the parent.
- `task` — Luna/high via `@task`. Implement clearly specified changes and run
  focused tests. Return design ambiguity to the parent.
- `sonic` — Luna/medium via `@smol`. Small mechanical edits and data collection.
- `reviewer` — Astra/high via the managed `@slow` override. Independently review
  correctness and regressions using the bundled review instructions.
- `security-reviewer` — Astra/high via the managed `@slow` override. Perform
  evidence-backed security review without inheriting a worker's model.

Do not dispatch `librarian`, `conversation-analyzer`, or `designer` merely
because a policy or model role mentions them: they are not installed by this
configuration. Project or extension agents may provide additional names; check
actual discovery before using them. Project definitions can override user and
bundled definitions.

## Escalation and delegation hygiene

- Give each subagent a self-contained brief with the goal, constraints,
  interfaces, evidence, and exact acceptance criteria.
- Use `explorer` when a scout's evidence exposes relationships beyond its scope;
  there is no mandatory sequence for every task.
- If a worker fails or finds ambiguity, return evidence to the main session and
  re-scope the assignment. Do not silently retry on a stronger model.
- Use `reviewer` or `security-reviewer` for independent verification when a wrong
  judgment is expensive. The optional Luna advisor is not a substitute.
- Parallelize independent read-heavy work. Avoid concurrent edits to overlapping
  files. Keep review independent of implementation.
- Keep architectural decisions in the main session; workers receive assignments
  whose decisions are already bounded.
