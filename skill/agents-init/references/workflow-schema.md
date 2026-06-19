# Workflow Schema

Use this reference when initializing, adopting, recovering, validating, or saving project state.

## Required Files

```text
.workflow/current.yaml
.workflow/agents-init.yaml
.workflow/task.yaml
.workflow/open_threads.yaml
.workflow/verification.yaml
.workflow/thread_registry.yaml
.workflow/memory_points.yaml
```

## `current.yaml`

Must answer:

- project;
- status;
- mission;
- current_gate;
- active task;
- read_first files;
- next_action;
- open_questions;
- forbidden_claims;
- compression_recovery fields.

## `task.yaml`

Must contain:

- `active_task`;
- `queue`;
- PM fields: user value, acceptance, scope, non-goals;
- FDE fields: data contracts, interfaces, failure states, rollback/recovery;
- route: direct, grill, brainstorm, worker, maestro, ralph;
- evidence and verification.

## `open_threads.yaml`

Every open item needs:

- question;
- why it matters;
- owner;
- gate;
- blocks;
- evidence;
- unanswered points;
- options;
- next.

## `verification.yaml`

Every verification entry needs:

- commands or browser/visual evidence;
- `proves`;
- `does_not_prove`;
- risks;
- next verification.

Empty verification logs, placeholder missions, and `active_task: null` are allowed for a fresh template but must be reported as `static_or_incomplete`. They do not prove a project is ready for long-task execution.

## `thread_registry.yaml`

Track:

- active main thread;
- historical/superseded main threads;
- worker threads;
- Maestro delegate ids;
- native subagent ids if useful;
- receipt status.

When a new main thread takes over, it must recover state first. If a real thread id is known, register it and mark the old main historical or superseded.

## `memory_points.yaml`

Use this file for active repeated corrections, direction changes, and compression-sensitive facts. It is not a second rule wall.

Each memory point needs:

- `id`;
- `status`: active, superseded, rejected, or needs_user_acceptance;
- `source`;
- `claim`;
- `applies_when`;
- `does_not_apply_when`;
- `evidence`;
- `supersedes`;
- `gate`;
- `last_seen`.

Close or supersede memory points when the user changes direction. Promote stable reusable lessons to Maestro spec/knowhow instead of growing this file indefinitely.

## Document Lifecycle

State files are working memory, not a history dump:

| Layer | Maintenance Rule |
| --- | --- |
| `current.yaml` | overwrite to the current truth |
| `task.yaml` | update queue/status/contracts, remove or park obsolete steps |
| `open_threads.yaml` | close, merge, or supersede stale questions |
| `memory_points.yaml` | keep atomic active corrections only |
| `verification.yaml` | append evidence, then summarize old evidence when it becomes noisy |
| receipts/archive | keep raw worker/model outputs out of active rules |
| Maestro spec | stable constraints |
| Maestro knowhow | reusable recipes, decisions, and session compacts |
| Maestro KG/search | code graph, impact, insertion, and cross-source retrieval |

An orchestration decision must say which layer is updated. If it only says "write another summary", the maintenance step is incomplete.

## Compression Recovery Output

Before compression or handoff, write a short recovery brief with:

```text
recovered_goal:
current_gate:
active_task:
open_threads:
evidence:
next_action:
forbidden_claims:
```

`save-state.ps1` can generate `.workflow/session-recovery-brief.md`, but the main agent must update the source files before using it as a handoff.
