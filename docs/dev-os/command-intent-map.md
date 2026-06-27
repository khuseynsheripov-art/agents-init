# Command Intent Map

The user does not need to memorize exact commands. Route natural language to the same actions.

| User says | Main agent should do |
| --- | --- |
| `$agents-init menu` / "agents-init help" / "what can you do" | Show the short natural-language menu, then ask what project or task to route. |
| `$agents-init orchestrate` / "direction feels wrong" / "how should we proceed" | Recover state, infer semantic signals, and decide direct/Maestro/Codex App/human gate routing. |
| "initialize this project" | Create missing Agents Init files, then update `.workflow/current.yaml`. |
| "adopt this existing project" | Do not overwrite. Classify old docs/TODO/rules and create sidecar `.workflow`. |
| "update agents-init" / "upgrade this skill" / "pull latest skill" | Run self-update from GitHub, reinstall the skill, then optionally upgrade this project workflow. |
| "recover this project" / "where are we" | Read `.workflow/current.yaml`, `task.yaml`, `open_threads.yaml`, `verification.yaml`, `thread_registry.yaml`. |
| "check agents-init config" / "doctor" | Run workflow validation plus Maestro/Codex environment diagnosis. |
| "pressure-test this skill" | Print pressure-test prompts and expected routes. |
| "I do not know which command to use" / "help me decide the route" | Run route-intent and preserve matched signals in open threads. |
| "register main thread" | Record the active main Codex thread id in `.workflow/thread_registry.yaml` when available. |
| "agents-init main" / "enter main orchestration" | Optional shortcut: recover state, analyze whether dynamic main/multi-worktree orchestration is needed, then propose topology before creating or dispatching branches. |
| "I am fuzzy" / "I cannot express this clearly" | Restate goal, list uncertainty, ask at most 1-3 questions. |
| "I am unhappy with the UI" | Create/update a UX issue first; do not jump straight to code. |
| "analyze product/source/sample options" | Create/update a sample decision or research task with evidence boundaries. |
| "multi-perspective review" / "PM/FDE review" | Use PM/FDE/UX/Data/Test views; synthesize into one task card or plan. |
| "open worker" / "open Codex sub-session" / "parallel analysis" | Register worker in `thread_registry.yaml`, give one bounded task and receipt contract. |
| "create worktree branches" / "branch_plan" / "completion_notice" / "data_packet" / "chairman_brief" / "parked_waiting_next_packet" | Use main-worktree orchestration: `task_packet -> branch_plan -> completion_notice -> data_packet -> chairman_brief -> parked_waiting_next_packet`. |
| "read worker receipt" / "ingest worker output" | Read worker output, accept/reject receipt, update workflow and verification. |
| "use Maestro/Ralph" | Use only after the current gate and human pause points are clear. |
| "ask Claude to challenge this" / "second model review" | Build a compact packet, smoke the route, capture raw output, and ingest a model receipt. |
| "small clear task" | Execute directly with completion standard and verification. |
| "save before compression" / "handoff to a new session" | Update current/task/open_threads/verification and write a recovery brief. |
| "evidence was not fully read" / "rg found nothing" / "evidence exhaustion" | Run context hygiene guardrail with `negative_searches`, `not_read_open_gap`, and proof boundaries; `rg` alone is not evidence exhaustion. |

## Route Intent Caveat

Natural-language routing is advisory. If one prompt contains multiple signals, do not discard the weaker signals. Put them into `open_threads.yaml` or the task card so they can be handled after the first gate.

If the phrase is not in this table, do not assume direct mode. Use the main-agent orchestration loop.

`agents-init main` is optional. The user can keep saying `agents-init` or use natural language; the main agent decides from recovered state whether a single-project session, bounded worker, or dynamic multi-worktree orchestration is appropriate.
