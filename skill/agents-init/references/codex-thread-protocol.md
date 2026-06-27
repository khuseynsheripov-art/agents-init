# Codex Thread Protocol

Use this reference when the user wants multi-session work, worker threads, cross-thread communication, or a new main session handoff.

## Roles

```text
main thread = orchestrator and final judge
one-shot session = one bounded task, one receipt, archive after main ingest
continuous session = reusable role or MVP context, one bounded task at a time
disposable worker = default one-shot session
durable role session = continuous session for repeated bounded work in one role/domain
mvp session = continuous session for one visible product slice
branch actor = worktree/session owner for one bounded task_packet
```

Workers do not decide product direction.

## Lifecycle Decision

Decide lifecycle before dispatch:

| Lifecycle | Use When | Memory Rule | Close Rule |
| --- | --- | --- | --- |
| one_shot | isolated analysis, implementation, verification, log/doc triage, second opinion | worker does not own durable memory; main ingests useful findings | archive/close after receipt accepted or rejected |
| continuous | repeated UX/sample/codebase/QA/knowledge role or MVP slice | may keep scoped notes under `.workflow/roles/<role_id>/`; still returns one receipt per task | retire or supersede when scope changes |

Default to `one_shot`. Use `continuous` only when role history prevents real repeated setup or memory loss.

Use branch packet lifecycle only for dynamic main/multi-worktree orchestration. Ordinary bounded workers can return `worker_receipt.yaml` without `task_packet -> branch_plan -> completion_notice -> data_packet -> chairman_brief -> parked_waiting_next_packet`.

For branch actors, `completion_notice` is not acceptance. The branch normally enters `parked_waiting_next_packet` after returning a receipt/data packet until the main agent ingests it and issues a new packet or archives the branch.

## Before Dispatch

The main agent must define:

- task id;
- bounded question;
- read/write scope;
- allowed files;
- must-not-edit files;
- expected artifact;
- receipt template;
- what the task proves and does not prove.
- lifecycle: `one_shot` or `continuous`;
- conflict set and whether any files overlap with other active sessions.

Update `.workflow/thread_registry.yaml` before or immediately after dispatch.

## Worker Prompt

```text
You are a bounded worker for this project.

Task:
<one bounded task>

Scope:
<files/areas>

Rules:
- Do not decide product direction or acceptance gates.
- Do not overwrite unrelated work.
- Return a receipt using .workflow/templates/worker_receipt.yaml.
- Include proves, does_not_prove, evidence, risks, open_threads, next.
- If this is one_shot, do not keep role memory; main will ingest useful findings.
- If this is continuous, keep notes only in your scoped role area unless main grants more.
```

## Receipt Ingest

The main agent must:

1. Read the worker output.
2. Check scope and evidence.
3. Accept, reject, or request revision.
4. Update `verification.yaml`, `open_threads.yaml`, and `thread_registry.yaml`.
5. Close/archive one-shot workers when tools allow.
6. For continuous sessions, update last receipt and retire/supersede if the scope changed.

Use receipt ingest in two phases:

- Shape check: `ingest-receipt.ps1 -ProjectPath <project> -ReceiptPath <receipt.yaml> -Json` reports whether the receipt is eligible for main-agent review. It does not accept the work.
- Explicit apply: after artifact inspection and a main-agent decision, use `ingest-receipt.ps1 -Apply -Decision accepted|rejected` with the project and receipt path, or the full form `ingest-receipt.ps1 -ProjectPath <project> -ReceiptPath <receipt.yaml> -Apply -Decision accepted|rejected -Json`.
- Wrapper path: `init-agents.ps1 -ProjectPath <project> -Mode ingest-receipt -ReceiptPath <receipt.yaml> -ApplyReceipt -ReceiptDecision accepted|rejected`.

Applying a receipt appends decision evidence to `verification.yaml` and updates the matching worker/delegate/model record in `thread_registry.yaml` with receipt status, receipt path, and main-agent decision time when a matching actor id is present.

Receipt apply records the main-agent receipt decision; it does not replace UI/sample/business human gates, artifact inspection, product direction judgment, or user-visible acceptance evidence.

## Waiting And Status Updates

Worker dispatch is not a fixed-interval recall loop. After the main agent sends one bounded worker task, the normal path is natural completion: wait for the worker receipt or for the user to ask for status.

Do not fixed-interval poll, nudge, or summarize worker status just because 30 seconds passed. Status checks are appropriate only when:

- the user asks for status;
- the worker has an explicit deadline or timeout;
- a tool reports completion, failure, or interruption;
- the main agent needs to cross a human gate before continuing;
- multiple active workers may conflict and the registry needs a coordination update.

If a worker is still running, the main agent may give a short user-facing note and then keep waiting. Started work is not evidence. Only returned receipts, raw output, or inspected artifacts can be ingested.

## With Claude Or Other CLI Models

Codex App multi-session is not the same transport as Claude Code `cc2`.

Use Codex App sessions when the worker should be visible as a reusable Codex thread, can receive messages through Codex App thread tools, or should maintain role/MVP context inside Codex App.

Use `cc2` when the user wants Claude's model strengths. Claude participation should still look like a worker receipt to the main agent:

```text
main Codex creates packet
cc2 one-shot or resumed session answers
main Codex converts output into model_review_receipt
main Codex updates .workflow and decides next gate
```

Do not expect Codex App worker threads and Claude TUI sessions to message each other directly. The main agent is the router unless Maestro delegate or another bridge is proven working.

## New Main Session

If the main agent changes:

1. Read `.workflow/current.yaml`.
2. Read `.workflow/thread_registry.yaml`.
3. Register the new id if available.
4. Mark old main ids as historical/superseded when appropriate.
5. Print recovered goal, gate, evidence, open threads, next action.

If the real thread id is unknown, use `current` and ask for the id only when cross-thread send/read is required.
