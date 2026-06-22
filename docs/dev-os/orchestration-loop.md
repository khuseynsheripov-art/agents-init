# Main Agent Orchestration Loop

Use this loop whenever the task is fuzzy, long, UI-heavy, sample-heavy, multi-agent, Maestro-related, or not covered by exact command examples.

## Loop

1. Recover state from `.workflow`.
2. If the user references previous work, pages, screenshots, audits, ports, samples, direction corrections, or old-project insertion, retrieve anchors before asking questions.
3. State recovered anchors with what each proves and does not prove.
4. If anchors conflict with the current artifact, write the root diagnosis: prior mainline, current observed artifact, contradiction, and first upstream confirmation.
5. Restate the likely goal in plain language.
6. Infer semantic signals from the user's meaning, not just keywords.
7. Classify the request: direct, grill, brainstorm, plan, worker, Maestro, Ralph, model review, or acceptance.
8. State the current gate and the claim being reduced.
9. If the next question asks the user to approve a product/UI/workflow shape, disclose consequences first: visible change, integration mode, what yes authorizes, what remains blocked, deferred paths, rollback/reframe.
10. If fuzzy, ask at most 1-3 upstream questions and create/update `open_threads`.
11. Create or update a PM + FDE task card or orchestration decision.
12. Route work:
   - direct for small clear tasks;
   - worker for bounded independent work;
   - Maestro for clear command chains;
   - Ralph for clear lifecycle work with human gates.
13. Ingest artifacts and receipts.
14. Update `current`, `task`, `open_threads`, `verification`, and `thread_registry`.
15. State what is proven, what is not proven, and the next action.

## Maestro And Codex App Decision

Use Maestro/Ralph for clear lifecycle or role-routed execution after gates are known. Use Codex App worker sessions for bounded independent tasks where a receipt saves main-thread context. Use neither when the work is product direction, acceptance, or clarification.

`route-intent` is only an aid. If it misses the user's phrasing, the main agent still must infer intent and record the decision.

Visible slices are evidence, not acceptance. A route, screenshot, smoke test, or generated sample can prove something exists and is inspectable, but it does not prove the user accepts the UI, workflow entrance, sample choice, generated-media quality, or product direction.

## Receipt Ingest

Accept a receipt only if it includes:

- task id and scope;
- files read/changed;
- evidence;
- open questions;
- `does_not_prove`;
- next recommended step.

Reject or return it if the worker made product direction decisions, skipped evidence, or crossed a human gate.
