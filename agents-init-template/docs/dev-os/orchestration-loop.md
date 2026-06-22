# Main Agent Orchestration Loop

Use this loop whenever the task is fuzzy, long, UI-heavy, sample-heavy, or multi-agent.

## Loop

1. Recover state from `.workflow`.
2. Classify the user request: direct, grill, brainstorm, plan, worker, Maestro, Ralph, or acceptance.
3. State the current gate and the claim being reduced.
4. If fuzzy, ask at most 1-3 questions and create/update `open_threads`.
5. Create or update a PM + FDE task card.
6. Route work:
   - direct for small clear tasks;
   - worker for bounded independent work;
   - Maestro for clear command chains;
   - Ralph for clear lifecycle work with human gates.
7. Ingest artifacts and receipts.
8. Update `current`, `task`, `open_threads`, `verification`, and `thread_registry`.
9. State what is proven, what is not proven, and the next action.

## Receipt Ingest

Accept a receipt only if it includes:

- task id and scope;
- files read/changed;
- evidence;
- open questions;
- `does_not_prove`;
- next recommended step.

Reject or return it if the worker made product direction decisions, skipped evidence, or crossed a human gate.
