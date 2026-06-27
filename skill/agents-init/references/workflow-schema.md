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
.workflow/authority_index.yaml
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
- worktrees and branch actors when dynamic main orchestration is active;
- task_packet, branch_plan, completion_notice, data_packet, parked_waiting_next_packet, and receipt paths;
- Maestro delegate ids;
- native subagent ids if useful;
- receipt status.

When a new main thread takes over, it must recover state first. If a real thread id is known, register it and mark the old main historical or superseded.

For dynamic main/worktree orchestration, `parked_waiting_next_packet` is a normal waiting state after one bounded branch task. It is not task acceptance, merge readiness, product completion, or failure. `completion_notice` is not acceptance; the main agent must inspect receipts/data packets, update workflow heads, and produce a user-facing brief when a user gate or next task decision is needed.

Worktree records should include path, branch, base/head sha or an explicit unknown reason, merge target, dirty state, active main, owning task, branch plan, completion notice, parked packet, gate, human gate status, owned paths, and conflict set.

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

## `authority_index.yaml`

This is the runtime authority ledger. It records which documents and receipts are current authority, active evidence, superseded, promoted, or archived.

Required sections:

- `current_authority`;
- `active_evidence`;
- `superseded`;
- `promoted`;
- `archived`;
- `closeout_updates`.

`docs/plans/index.yaml` may mirror this information for humans, but `.workflow/authority_index.yaml` is the source the next main agent should recover first.

## Document Lifecycle

State files are working memory, not a history dump:

| Layer | Maintenance Rule |
| --- | --- |
| `current.yaml` | overwrite to the current truth |
| `task.yaml` | update queue/status/contracts, remove or park obsolete steps |
| `open_threads.yaml` | close, merge, or supersede stale questions |
| `memory_points.yaml` | keep atomic active corrections only |
| `authority_index.yaml` | mark current authority, active evidence, superseded docs, promotions, and archives |
| `verification.yaml` | append evidence, then summarize old evidence when it becomes noisy |
| receipts/archive | keep raw worker/model outputs out of active rules |
| Maestro spec | stable constraints |
| Maestro knowhow | reusable recipes, decisions, and session compacts |
| Maestro KG/search | code graph, impact, insertion, and cross-source retrieval |

An orchestration decision must say which layer is updated. If it only says "write another summary", the maintenance step is incomplete.

## Workflow Closeout Receipt

Use `.workflow/templates/workflow_closeout_receipt.yaml` or `closeout-workflow.ps1` when a route, gate, direction, handoff, promotion, receipt ingest, task closeout, or archive cleanup changes the active workflow head.

The closeout receipt must name:

- reason;
- active head before and after;
- updated heads;
- authority index updates;
- Maestro promotions, if any;
- session recovery update;
- validation status;
- `proves`;
- `does_not_prove`.

The receipt records lifecycle closure. It does not prove product acceptance, UI/sample/generated-image acceptance, or business readiness.

For branch/worktree lifecycle closeout, include branch_plan, worktree_registry, completion_notice, and parked_packet head mutations. A receipt accepted by main does not imply the branch is merged or archived unless those heads are explicitly updated.

## Evidence Exhaustion Check

Use `.workflow/templates/evidence_exhaustion_check.yaml` only when a high-risk evidence-heavy task, context compression, absence claim, or system-error recovery needs it.

Minimum fields:

- methods;
- positive evidence;
- negative_searches;
- not_read_open_gap;
- excluded noise;
- confidence;
- proves and does_not_prove.

`rg` alone is not evidence exhaustion. It only proves that named patterns did not match a named scope.

## Document Triage Receipt

When documents are unfinished, decisions changed mid-conversation, receipts are scattered, or old plans still look active, classify each artifact before writing more. Use `.workflow/templates/document_lifecycle_receipt.yaml` or an equivalent compact note.

Every triaged artifact is one of: active, unresolved, superseded, archived, promoted, or rejected. The receipt must name active claims, unresolved questions, superseded-by target, promotion target, restore or trace reference, proves, does_not_prove, and next action.

Do not append another summary when the real task is knowledge cleanup. First classify artifacts, move unresolved questions into `open_threads.yaml`, add or supersede atomic memory points, promote stable rules to spec/knowhow, archive raw receipts with restore pointers, and update `current.yaml`/`task.yaml` to the current truth.

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
