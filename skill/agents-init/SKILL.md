---
name: agents-init
description: Use when initializing or adopting a project/worktree with the user's agent workflow, including fuzzy requirement clarification, main-agent orchestration, Maestro/Ralph routing, Codex App multi-session workers, context recovery, receipts, UI/sample/image gates, or old-project salvage.
---

# Agents Init

Use this skill to turn a project or worktree into a recoverable, human-gated development system. It is a main-agent console and Maestro adapter, not a replacement for product judgment.

## Thin Entry Loop

Do not start from the command menu. Start from the user's current words and recover the live contradiction.

For any non-trivial or context-referenced request, the main agent first runs this compact loop:

1. Recover `.workflow` and memory points.
2. Decide whether the user is continuing/correcting prior work or starting a new task.
3. Retrieve anchors for prior pages, audits, screenshots, plans, ports, samples, failures, or model debates.
4. Generate 2-3 competing interpretations of the user's intent.
5. Compare recovered mainline vs current artifact/proposal.
6. State the root diagnosis before asking questions.
7. Disclose consequences before asking the user to approve an option.
8. Ask the minimum upstream question, then choose direct work, worker, Maestro, Claude, or human gate.

Use heavy machinery only when the loop shows real need: old-project insertion, UI/sample/image/business gates, repeated correction, long-task recovery, multi-session conflict, or high-value multi-model review.

For product/UI/workflow placement, run the Product-System Fit Gate before implementation. Surface complaints such as "new page", "panel", "menu", "not integrated", "feels disconnected", or "too narrow" are weak signals only; infer whether the real issue is product structure, workflow ownership, interaction grammar, object boundaries, or temporary sidecar drift.

Integration means object ownership, workflow ownership, capability reuse, and native interaction grammar. Placement is only the visible expression. Moving a button into a page, panel, toolbar, or global navigation is not integration unless those ownership and reuse contracts are proven.

Correct direction is not enough. For product/UI/workflow fit, an answer fails if it only says "use the existing editor", "right panel", or "not a standalone page" without filling or explicitly blocking `evidence_bound_product_fit`.

When the user is asking "is this the previous analysis, a new page, or the old page?", the answer must expose a short user-visible Product-System Fit receipt before asking for confirmation:

- recovered anchors: what `.workflow`, memory, docs, or browser evidence was actually read;
- root diagnosis: recovered mainline vs current sidecar/workbench/artifact;
- PFIT status: `passed`, `blocked`, or `summary_only_failure`;
- consequence: what a "yes" authorizes and what it does not authorize;
- first question: one upstream confirmation, not downstream UI/model/details.

## First Decision

| Situation | Route |
| --- | --- |
| No `AGENTS.md` and no `.workflow` | `init` with the project template |
| Existing docs/rules/TODO but no `.workflow` | `adopt`; add sidecar workflow files without overwriting |
| Existing `.workflow/current.yaml` | `recover`, then `orchestrate` for any non-trivial request |
| Small clear task | `direct`; state completion standard and verification |
| Fuzzy product/UI/sample/image task | `context-retrieve -> clarify/grill`; cite recovered anchors before asking 1-3 questions |
| Chaotic second-development task | `blueprint -> salvage -> insertion plan -> visible slice` |
| Clear lifecycle task | Maestro/Ralph after gates are known |
| Multi-session work | main thread dispatches bounded workers and ingests receipts |
| Dynamic main / multi-worktree orchestration | `recover -> main-orchestration-intake -> propose topology/task_packet -> human gate -> dispatch branch` |
| Evidence-heavy compression or absence claim | `context-hygiene -> evidence_exhaustion_check -> partial_continue or return to main` |

If the user says they are confused, dissatisfied, unsure, wants a long task, or references prior work, do not implement first. Recover or create project state, retrieve relevant prior-task anchors when applicable, then make a main-agent orchestration decision. Do not use keyword matching as the final decision.

If the prompt contains "previously", "last time", "we already discussed", prior ports/pages, screenshots, audits, samples, direction corrections, or project-specific terms, context retrieval comes before clarification. Ask questions only after stating what prior evidence was found and what it proves or does not prove.

Workflow upgrade/version checks are maintenance evidence, not user intent. Do not ask whether the project is v1/v2, mention protocol versions, or make "upgrade mode" part of the first user-facing diagnosis unless the user explicitly asks about upgrading/versioning or required workflow files are missing. For a recovered project, summarize only: "workflow is recoverable/valid" and then return to the user's product/process contradiction.

## References To Load

Read only the relevant reference:

| Need | Read |
| --- | --- |
| User pain rules and stop gates | `references/pain-point-rules.md` |
| Main-agent semantic orchestration | `references/main-agent-orchestration.md` |
| `.workflow` schema and recovery fields | `references/workflow-schema.md` |
| Maestro/Ralph/delegate/Windows limits | `references/maestro-routing.md` |
| Codex App multi-session worker protocol | `references/codex-thread-protocol.md` |
| Dynamic main, worktree, branch packet orchestration | `references/main-worktree-orchestration.md` |
| Context hygiene and evidence exhaustion | `references/context-hygiene-and-evidence-exhaustion.md` |
| Old project/worktree salvage | `references/adoption-salvage.md` |
| Role and model/tool routing | `references/multi-model-role-policy.md` |
| Multi-model or `cc2`/Claude shared-context review | `references/multi-model-shared-context.md` |
| Day-to-day natural-language usage and role configuration | `references/usage-playbook.md` |
| Receipt acceptance/rejection | `references/receipts.md` |
| Ozon/Canvas drift pressure-test example | `references/case-studies/ozon-canvas.md` |

## Init Or Adopt

Use the bundled script:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File "<skill>\scripts\init-agents.ps1" -ProjectPath "<project>" -Mode auto
```

Behavior is non-destructive:

- create missing template files;
- skip existing files;
- never overwrite project docs, TODO, `AGENTS.md`, or `.workflow`;
- print an `AGENTS.md` router snippet when an existing project needs wiring;
- patch existing files only after reading them.

Use `-ApplyAgentEntry` only after reading the existing `AGENTS.md` and when the user asked to wire the project.

## User-Facing Menu

When the user asks "what can this skill do?", "menu", "help", "how do I use this", or selects the skill without a concrete request, show a short natural-language menu first. Do not force the user to memorize commands.

```text
Agents Init can help with:
1. Init/adopt project: create or upgrade a recoverable .workflow.
2. Recover context: report goal, gate, evidence, open issues, and next step.
3. Clarify fuzzy intent: restate intent, find uncertainty, ask 1-3 upstream questions.
4. Plan/blueprint: PM + FDE plan, old-project salvage, insertion plan.
5. Workers: dispatch bounded Codex workers and ingest receipts.
6. Main/worktree orchestration: optionally enter `agents-init main`, propose branch topology, issue task_packet, ingest branch_plan/completion_notice/data_packet, brief the user, then park or dispatch next.
7. Maestro/Ralph: route lifecycle/delegate work after gates are clear.
8. Claude/multi-model: build a compact packet, run a receipt-backed second view.
9. UI/sample/image gate: require visible evidence and user acceptance.
10. Evidence hygiene: for high-risk compression or absence claims, record methods, negative_searches, not_read_open_gap, and proof boundaries.
11. Self-update: pull latest agents-init and optionally upgrade this project.
12. Closeout workflow: record route/gate/direction/handoff/promotion/archive transactions.
13. Save handoff: write recoverable state before compression or handoff.
```

If the user already gave a concrete intent, skip the menu and route the request.

## Reference Command Menu

These are reference actions for the main agent. Do not present them as the primary user interface and do not require the user to memorize them:

| Command | Meaning |
| --- | --- |
| `$agents-init menu` | Show status and available actions. |
| `$agents-init recover` | Read `.workflow` and report goal, gate, evidence, open threads, next action. |
| `$agents-init doctor` | Diagnose project workflow, Maestro availability, delegate routing, and Codex/Windows limits. |
| `$agents-init validate` | Check required files and false-completion risks. |
| `$agents-init pressure-test` | Generate realistic prompts to test whether the workflow catches drift. |
| `$agents-init orchestrate` | Main agent recovers state, interprets semantic intent, and decides direct/Maestro/Codex App/human gate routing. |
| `$agents-init route-intent` | Convert fuzzy natural language into a recommended route plus matched signals. |
| `$agents-init grill` | Clarify a fuzzy requirement before planning or coding. |
| `$agents-init brainstorm` | Run PM/FDE/UX/Data/Test perspectives and synthesize. |
| `$agents-init multi-perspective-review` | Review a fuzzy/long/UI/sample/old-project task through PM/FDE/UX/Workflow/Maestro/Risk views before execution. |
| `$agents-init blueprint` | Map requirement -> modules -> risks -> acceptance before implementation. |
| `$agents-init plan` | Produce a PM + FDE plan with gates and verification. |
| `$agents-init main` | Optional shortcut to enter or resume dynamic main/worktree orchestration; natural-language `agents-init` remains the default entry. |
| `$agents-init register-main` | Register or update the active main Codex thread id. |
| `$agents-init dispatch-worker` | Create/message one bounded worker with a receipt contract. |
| `$agents-init ingest-receipt` | Accept/reject worker output and update `.workflow`. |
| `$agents-init closeout-workflow` | Record a route, gate, direction, handoff, promotion, or archive cleanup closeout. |
| `$agents-init route-maestro` | Choose direct, worker, Maestro, or Ralph. |
| `$agents-init multi-model-packet` | Build a shared context packet for Claude/Codex/Maestro/Codex App review. |
| `$agents-init invoke-maestro-skill` | Call Maestro spec/knowhow/search/KG/wiki/domain/workspace/msg/overlay/delegate-config and return receipt-shaped anchors. |
| `$agents-init invoke-claude-review` | Run one bounded Claude review through Maestro delegate, read raw output, and return a receipt-shaped result. |
| `$agents-init save-state` | Update recovery state before compression or handoff. |
| `$agents-init maintain-knowledge` | Main agent updates, closes, promotes, indexes, or archives workflow knowledge instead of appending forever. |
| `$agents-init self-update` | Pull the latest agents-init source from GitHub, install the skill, then optionally upgrade the current project's `.workflow`. |

Natural language should route to the same actions. Examples:

- "I cannot explain it clearly, but the direction feels wrong" -> `orchestrate -> clarify/grill`
- "I am fuzzy" -> `grill`
- "I am unhappy with the UI" -> create/update `ux_issue.yaml`
- "Analyze product/source/sample options" -> `sample_decision` plus research task
- "The second-development branch failed; salvage the old project" -> `blueprint -> salvage -> insertion plan`
- "Open sub-sessions to analyze separately" -> `dispatch-worker`
- "Create or resume main/worktree orchestration" -> `recover -> main-orchestration-intake`; do not create worktrees before recovery, goal clarification, and object/module boundary analysis
- "This branch returned branch_plan/completion_notice/data_packet" -> `main ingest -> chairman_brief -> parked_waiting_next_packet or next task_packet`
- "Evidence was compressed / not fully read / rg found nothing" -> `evidence_exhaustion_check`; rg alone is not evidence exhaustion
- "This report changes the plan / close the old path" -> `closeout-workflow`
- "Save state before compression" -> `save-state`
- "This is a small clear task; do it directly" -> `direct`
- "Update agents-init, then upgrade this project" -> `self-update -> optional project upgrade`

`orchestrate` is the real decision loop. `route-intent` is advisory only. If multiple signals appear, use the first recommended route as the next gate but preserve all matched signals in open threads. For example, "UI 不满意 + 开子会话 + 分析爆品样本" normally starts with UI/sample acceptance clarification, then dispatches bounded workers.

Treat `route-intent.ps1` as weak-signal output, not semantic understanding. When user wording refers to previous work, current browser pages, old audits, ports, samples, or repeated corrections, bounded context retrieval and evidence citation outrank the route-intent recommendation.

## Self Update

When the user asks to upgrade or update agents-init itself, update the installed skill from the GitHub distribution repo first, then upgrade the named project workflow only if requested:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File "$env:USERPROFILE\.codex\skills\agents-init\scripts\update-agents-init.ps1" -ProjectPath "<project>"
```

This uses a local source clone at `%USERPROFILE%\.codex\skill-sources\agents-init` by default. It does not decide product direction and does not make the project live-proven. After self-update, still run `recover`, `validate`, and the semantic orchestration loop for the user's actual request.

## Main Agent Duties

The main agent owns:

- semantic interpretation of the user's words, including meanings not covered by examples;
- requirement clarification;
- task ordering and gate choice;
- active knowledge maintenance: update current state, close or supersede old threads, promote stable lessons to Maestro spec/knowhow, and use KG/search for code context;
- PM/FDE/UX/Data/Test/Workflow/Maestro/Risk synthesis;
- worker or delegate dispatch;
- receipt ingest;
- `.workflow/current.yaml`, `task.yaml`, `open_threads.yaml`, `verification.yaml`, `thread_registry.yaml`, and `authority_index.yaml`;
- final judgment about what is proven.

For non-trivial requests, the main agent must produce an orchestration decision before execution. Use `.workflow/templates/orchestration_decision.yaml` or an equivalent concise decision note.

That decision must include a knowledge lifecycle judgment. Do not keep appending documents by default. Decide what to overwrite, close, supersede, promote, index, or archive:

- current task state stays in `.workflow/current.yaml` and `task.yaml`;
- current document authority and supersession lives in `.workflow/authority_index.yaml`;
- unresolved questions stay in `open_threads.yaml` until closed or superseded;
- repeated corrections and direction changes become atomic `memory_points.yaml` entries;
- stable reusable rules become Maestro `spec` entries;
- reusable workflows, receipts, session compacts, and case lessons become Maestro `knowhow` entries;
- code insertion, impact, and old-project salvage context should use Maestro `kg index/sync/search/context` when available;
- raw worker/model transcripts are receipts or archive evidence, not active rules.

When a route, gate, direction, handoff, promotion, or archive decision changes the active head, use `closeout-workflow.ps1` or `.workflow/templates/workflow_closeout_receipt.yaml`. The closeout records what changed in `.workflow/authority_index.yaml`, appends verification evidence, and refreshes `.workflow/session-recovery-brief.md`. It is a lifecycle receipt, not product acceptance.

For fuzzy, long-running, old-project, UI/sample/image, Maestro/Codex-App, or multi-model requests, the decision must also include a multi-perspective review. Use `.workflow/templates/multi_perspective_review.yaml` or an equivalent concise note. The minimum views are PM, FDE, UX/visible acceptance, Workflow/context engineering, Maestro/Codex App orchestration, and Risk/over-engineering. A view is not valid unless it includes evidence, risk or objection, and next action.

Workers may analyze, implement, or verify one bounded task. Workers must not decide product direction, UI acceptance, generated image quality, sample acceptance, external publishing, or seller-ready claims.

## Human Gates

Pause before crossing:

- fuzzy product direction;
- UI/UX satisfaction;
- sample/reference selection;
- generated image quality;
- source/reference fact boundary;
- existing workflow or Canvas-like surface shape;
- export/publish/seller-ready claims;
- external account/platform writes.

Backend tests never prove these gates. Use screenshots, browser smoke, sample outputs, or explicit user acceptance.

## Maestro And Threads

Maestro/Ralph is a workflow executor and knowledge/lifecycle engine. Use it after the current gate is clear.

Maestro skills are not Claude delegate. Treat `spec/knowhow/search/KG/wiki/domain/workspace/msg/overlay` as first-class orchestration surfaces for local memory, reusable rules, code graph context, cross-workspace knowledge, coordination, and non-invasive workflow patches. Use `invoke-maestro-skill.ps1` when the main agent needs those anchors, then synthesize what they prove and do not prove before deciding. Search/spec/knowhow/KG output is context evidence, not product acceptance and not multi-model review.

Project-level Maestro Codex skills are a separate surface from Maestro CLI knowledge commands. When the user asks for Maestro Grill, Maestro Next, Ralph, Quick, Learn, Guard, or another project-installed Maestro skill, do not stop at `$agents-init` or registry discovery. Verify availability with `maestro ralph skills --platform codex --json`, read the selected project skill's SKILL.md, and then either apply that skill's instructions in the current main-agent context or record why the skill is blocked by a human gate, missing evidence, or unsupported transport. Registry discovery alone is not execution, and `maestro <skill-name>` returning generic CLI help is not proof that the Codex skill ran.

Minimum accepted Maestro skill smoke: recover `.workflow`; retrieve Maestro search/spec/knowhow/KG anchors when relevant; verify the project skill is listed; read the selected project skill's SKILL.md; perform one bounded in-context skill action or explicitly block it; write a receipt with raw commands/files read plus `proves` and `does_not_prove`. Started, listed, or recommended work is not evidence until the main agent ingests the receipt or artifact.

## Dynamic Main / Multi-Worktree Orchestration

Use this only when recovered state and the user's goal show that one main agent should coordinate multiple worktrees, branch actors, or durable Codex App sessions. The default entry remains `agents-init`; `agents-init main` is an optional shortcut for explicitly entering or resuming this mode.

This mode is state-driven, not keyword-driven. Before creating or resuming worktrees, the main agent must recover `.workflow`, clarify the goal, identify object/module boundaries, disclose consequences, and decide whether the split is actually useful. Do not create worktrees before recovery, goal clarification, and object/module boundary analysis.

The generic packet lifecycle is:

```text
task_packet -> branch_plan -> completion_notice -> data_packet -> chairman_brief -> parked_waiting_next_packet
```

`completion_notice` is not acceptance. `data_packet` is input evidence, not final judgment. `chairman_brief` is the main-agent synthesis for the user after receipt/data-packet ingest. `parked_waiting_next_packet` is a normal waiting state after a bounded branch task; it is not failure, merge readiness, or product completion.

Do not hardcode Ozon B/S/C lanes, ERP paths, or business gates as generic agents-init rules. If a project already has local orchestrator rules, adapt to them and keep agents-init as the recoverable control-plane helper.

Read `references/main-worktree-orchestration.md` for the full rules and templates.

## Context Hygiene And Evidence Exhaustion

Use this as a low-frequency high-risk guardrail for branch compression, evidence-heavy tasks, absence claims, system errors, or user corrections that say evidence was not fully read. It is not the default path for small tasks.

Raw evidence belongs in files, receipts, artifacts, and indexes. Model context should carry bounded digests and the current decision head. `rg` alone is not evidence exhaustion; it can only prove that specific patterns did not match a specific searched scope.

When this guardrail is triggered, use `evidence_exhaustion_check.yaml` and record `methods`, `positive_evidence`, `negative_searches`, `not_read_open_gap`, excluded noise, confidence, and `does_not_prove`. Use `evidence_digest.yaml` before compression or handoff when raw evidence would overload the next session.

Read `references/context-hygiene-and-evidence-exhaustion.md` for the full guardrail.

For Codex App multi-session:

- main thread = orchestrator and final judge;
- one-shot session = one bounded task, one receipt, then archive after main ingest;
- continuous session = reusable role or MVP context; still one bounded task and one receipt per assignment;
- disposable worker = default one-shot session;
- durable role session = continuous session only when repeated role context is valuable;
- `thread_registry.yaml` indexes active and historical threads;
- `worker_receipt.yaml` is required.

Worker dispatch uses natural completion, not a no fixed-interval recall loop. After sending one bounded task, wait for the receipt unless the user asks for status, a deadline/tool event fires, a human gate is reached, or active workers may conflict. Started work is not evidence.

Creating a Codex App thread is user-visible. If thread tools are available and the user asks for multi-session work, register the worker and send a bounded prompt with the receipt contract.

Main-agent routing rule:

- Use Maestro/Ralph for clear stage/lifecycle work after human gates are known.
- Use Codex App workers for independent bounded tasks where receipts save context.
- Use both only when the main agent can ingest results and decide the next gate.
- Use neither when the actual task is clarification, product direction, UI/sample/image acceptance, or final judgment.

For multi-model work:

- distinguish `maestro_delegate`, `interactive_cli_continuous`, `capturable_cli_one_shot`, `capturable_cli_continuous`, `codex_app_one_shot`, and `codex_app_continuous`;
- do not claim a Claude or other non-Codex review happened until usable output or a pasted receipt exists;
- discover and smoke the local Claude route before use; wrappers such as `cc2`, default `claude`, and Maestro delegate are different routes;
- do not report "Claude unavailable" when only one route failed. Say which route failed and which route, if any, succeeded;
- default to one-shot Claude review for quota control; use `--resume <session_id>` only when the next question genuinely needs prior Claude context;
- if `cc2` opens an interactive TUI, treat it as user-driven conversation; generate `.workflow/templates/multi_model_context_packet.md` for the user to paste and ingest `.workflow/templates/model_review_receipt.yaml` afterward;
- if `cc2 --safe-mode -p ... --output-format json` works, treat it as capturable CLI review; store the session id only for bounded continuous analysis and retire it when the receipt is ingested;
- if Maestro delegate returns empty output or a model/auth error, record it as inconclusive in verification.

Async communication rule:

- Codex App tools can message Codex App threads.
- Maestro delegate can run async and receive `delegate message`.
- Maestro `agent-msg` is a coordination ledger, not proof that Claude/Codex consumed a message.
- `cc2 --resume` gives Claude continuity, but the main agent still sends each turn unless a separate bridge is proven.
- Treat the main agent as the router and receipt ingester across tools.

## Scripts

```powershell
# recover current project state
powershell -NoProfile -ExecutionPolicy Bypass -File "<skill>\scripts\recover-agents.ps1" -ProjectPath "<project>"

# validate workflow shape and risky false-completion claims
powershell -NoProfile -ExecutionPolicy Bypass -File "<skill>\scripts\validate-workflow.ps1" -ProjectPath "<project>"

# diagnose Maestro/Codex/App workflow readiness
powershell -NoProfile -ExecutionPolicy Bypass -File "<skill>\scripts\doctor-agents.ps1" -ProjectPath "<project>"

# run one bounded Claude review through Maestro and read raw output
powershell -NoProfile -ExecutionPolicy Bypass -File "<skill>\scripts\invoke-claude-review.ps1" -ProjectPath "<project>" -Task "<bounded analysis task>" -Json

# call non-Claude Maestro skills for memory, knowledge, KG, config, coordination, or overlays
powershell -NoProfile -ExecutionPolicy Bypass -File "<skill>\scripts\invoke-maestro-skill.ps1" -ProjectPath "<project>" -Skill search -Query "<task-relevant query>" -All -Json

# print pressure prompts for forward-testing this skill on the project
powershell -NoProfile -ExecutionPolicy Bypass -File "<skill>\scripts\pressure-test-agents.ps1" -ProjectPath "<project>"

# route fuzzy natural language to a workflow action
powershell -NoProfile -ExecutionPolicy Bypass -File "<skill>\scripts\route-intent.ps1" -ProjectPath "<project>" -Prompt "<user words>"

# create a bounded worker prompt and optional dispatch artifact
powershell -NoProfile -ExecutionPolicy Bypass -File "<skill>\scripts\make-worker-prompt.ps1" -ProjectPath "<project>" -TaskId "<id>" -Task "<task>" -Scope "<scope>"

# check whether a worker/delegate receipt is eligible for main-agent acceptance
powershell -NoProfile -ExecutionPolicy Bypass -File "<skill>\scripts\ingest-receipt.ps1" -ProjectPath "<project>" -ReceiptPath "<receipt.yaml>"

# apply an explicit main-agent receipt decision after artifact inspection
powershell -NoProfile -ExecutionPolicy Bypass -File "<skill>\scripts\ingest-receipt.ps1" -ProjectPath "<project>" -ReceiptPath "<receipt.yaml>" -Apply -Decision accepted|rejected -Json
powershell -NoProfile -ExecutionPolicy Bypass -File "<skill>\scripts\init-agents.ps1" -ProjectPath "<project>" -Mode ingest-receipt -ReceiptPath "<receipt.yaml>" -ApplyReceipt -ReceiptDecision accepted|rejected

# record a main-agent lifecycle closeout after route/gate/direction/handoff/promotion/archive changes
powershell -NoProfile -ExecutionPolicy Bypass -File "<skill>\scripts\closeout-workflow.ps1" -ProjectPath "<project>" -Reason route_change -TaskId "<task-id>" -Json
powershell -NoProfile -ExecutionPolicy Bypass -File "<skill>\scripts\init-agents.ps1" -ProjectPath "<project>" -Mode closeout-workflow -CloseoutReason route_change -CloseoutTaskId "<task-id>"

# write a session recovery brief before compression or handoff
powershell -NoProfile -ExecutionPolicy Bypass -File "<skill>\scripts\save-state.ps1" -ProjectPath "<project>"
```

Use validation before saying a project is configured, recovered, or ready for long-task execution.

`validate-workflow.ps1` may return valid with readiness `static_or_incomplete`. That means the file shape is acceptable but the project still has placeholders, no active task, or no evidence. Do not call that live-ready.

## Verification Levels

Be precise about claims:

| Level | Meaning |
| --- | --- |
| Static valid | Skill metadata and template shape pass checks. |
| Workflow valid | Project `.workflow` has required files and no obvious false-completion claim. |
| Recovery works | `recover-agents.ps1` can reconstruct goal, gate, evidence, and next action. |
| Pressure tested | Fresh prompt scenarios route correctly. |
| Live proven | A real user task completed with receipts and acceptance gates. |

Do not call configuration "solved" if only static/workflow validation passed. State what remains unproven.
