# Codex App Role Sessions

Use this when the user wants ongoing multi-session development, role agents, or MVP threads.

## Lifecycle Split

Codex App multi-session work has two top-level lifecycles:

| Lifecycle | Meaning | Use When | Memory Policy | Close Rule |
| --- | --- | --- | --- | --- |
| one_shot | 一次性任务会话 | One bounded analysis, implementation, verification, or log/doc triage task | Return one receipt; useful findings are ingested by main, then archived | Close/archive after receipt is accepted or rejected |
| continuous | 持续角色会话 | A role/domain/MVP slice will recur across days or multiple tasks | Keep role history, but write only scoped notes/receipts; main decides what becomes project memory | Stay active until role is retired, superseded, or its scope changes |

This split is decided before choosing the concrete session type.

Default to `one_shot` unless the repeated role context is clearly valuable. Use `continuous` only when reuse prevents real memory loss or repeated setup.

## Session Types

| Type | Use | Lifetime | Registry Required |
| --- | --- | --- | --- |
| main_thread | user conversation, orchestration, final judgment | active project owner | yes |
| disposable_worker | one bounded task and one receipt | one_shot | yes |
| durable_role_session | repeated bounded analysis for one role/domain | continuous | yes |
| mvp_session | one visible product slice with its own history | continuous unless explicitly temporary | yes |

Durable role sessions are different from native subagents. They are visible Codex App threads with recoverable history and can be reused. They are useful for repeated roles such as UX review, codebase mapping, sample research, QA verification, or an MVP slice.

Disposable workers are also different from native subagents: they are user-visible Codex App threads, but they should not become memory owners. They produce one bounded receipt, then the main agent ingests the useful part into `.workflow`, Maestro knowhow/spec/wiki, or a later memory point.

## Main-Agent Responsibilities

Before using a role session, the main agent must define:

- role purpose;
- allowed read scope;
- allowed write scope;
- forbidden decisions;
- receipt contract;
- conflict set;
- stop conditions.

The main agent owns the user-facing direction. Role sessions may propose, analyze, implement within scope, or verify; they do not accept product direction, UI quality, sample choice, generated image quality, or external writes.

## Conflict Rules

- Only one actor may write a shared file set at a time.
- Durable role sessions should write their own notes under `.workflow/roles/<role_id>/` unless explicitly scoped otherwise.
- Main state files are owned by main: `.workflow/current.yaml`, `.workflow/task.yaml`, `.workflow/open_threads.yaml`, `.workflow/verification.yaml`.
- Workers may append receipts only when explicitly instructed; otherwise main ingests and writes state.
- If two role sessions disagree, main records the disagreement in `open_threads` and decides the next gate.
- Before implementation fanout, compare `may_edit` sets and assign disjoint ownership.

## Registry Fields

```yaml
id:
source: codex_app
lifecycle: one_shot | continuous
type: disposable_worker | durable_role_session | mvp_session
role:
task_id:
scope:
may_read:
may_edit:
must_not_edit:
report_to:
status:
receipt_status:
last_receipt:
conflicts_with:
created_at:
last_active_at:
archive_rule:
```

## One-Shot Session Rules

Use for:

- isolated code or doc review;
- bounded repository search;
- one implementation patch in a non-overlapping file set;
- log/test failure analysis;
- "give me a second opinion on this specific plan".

Rules:

- one task;
- one receipt;
- no durable memory except what main explicitly ingests;
- may not maintain ongoing role notes;
- should be archived after receipt ingest.

## When To Reuse A Role Session

Reuse only if:

- the role/domain is the same;
- the old context helps;
- the previous receipt was accepted or the unresolved issue is still relevant;
- write scope does not conflict with current work.

Create a disposable worker instead if the task is one-shot, independent, or would pollute a durable role history.

## Continuous Session Rules

Use for:

- recurring UX review across visible slices;
- recurring sample/research analysis;
- codebase mapper for a large or old project;
- QA verifier that accumulates known checks;
- knowledge curator for specs/knowhow/wiki;
- MVP slice that needs its own sustained context.

Rules:

- still receives bounded tasks one at a time;
- returns one receipt per task;
- can keep role notes under `.workflow/roles/<role_id>/`;
- cannot decide product direction or human gates;
- must be retired or superseded when scope changes.

## MVP Session

An MVP session is a durable thread for one visible slice. It may coordinate analysis and implementation inside its own scope, but it still reports to main for user gates.

Good use:

```text
MVP session: Canvas Ozon suite visible slice
scope: one worktree, one route/page, one image workflow
stop: screenshot/user gate before expanding
```

Bad use:

```text
MVP session decides the product direction and keeps coding without main acceptance.
```
