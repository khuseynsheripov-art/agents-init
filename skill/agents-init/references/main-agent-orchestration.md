# Main Agent Orchestration

Use this reference when the user asks a fuzzy, strategic, long-running, multi-agent, Maestro, Codex App, UI, sample, image-generation, or learning/process question.

## Core Principle

The main agent is not a keyword router. It is the semantic orchestrator.

Scripts such as `route-intent.ps1` can expose weak signals, but they cannot decide product direction, ambiguity, gate readiness, Maestro/Ralph use, Codex App worker use, or final acceptance. If script output conflicts with the user's actual intent or project state, override the script and record why.

## Required Main-Agent Loop

Before implementation on any non-trivial request:

1. Recover project state from `.workflow`.
2. If the user references prior work, current pages, old audits, samples, screenshots, ports, direction corrections, or repeated clarification, retrieve context before asking questions.
3. Restate the user's likely goal in plain language.
4. Extract semantic signals, not only keywords.
5. Decide the current gate.
6. Decide whether this needs clarification, Maestro/Ralph, Codex App workers, direct work, or human acceptance.
7. Run or write the required multi-perspective review when the task is fuzzy, long-running, old-project, UI/sample/image, Maestro/Codex-App, or multi-model.
8. If a user confirmation is needed, disclose the concrete consequence before asking: visible route/page, integration mode, workflow axis, rejected alternatives, and what remains unproven.
9. Decide the knowledge lifecycle: update, close, supersede, promote to spec/knowhow, KG index/search, or archive.
10. Record the decision in an orchestration decision artifact or task card.
11. Only then dispatch work or implement.

## Semantic Continuation Loop

When the user references prior work or sounds like they are correcting direction, do not treat the prompt as a fresh requirement and do not route by keywords. Run a semantic continuation loop:

1. `current_words`: quote the user's immediate concern in your own words.
2. `continuation_signals`: list references to earlier pages, audits, screenshots, ports, plans, failures, model debates, or "didn't we already..." language.
3. `recovered_mainline`: cite the prior intended chain from `.workflow`, memory points, plans, receipts, Maestro search/KG, or local docs.
4. `current_artifact_or_plan`: cite what exists now or what the agent is about to do.
5. `competing_hypotheses`: name 2-3 possible meanings, including "new request" and "correction of drift" when both are plausible.
6. `contradiction_check`: explain whether the current artifact/proposal conflicts with the recovered mainline.
7. `root_diagnosis`: state the most likely upstream issue.
8. `first_question`: ask one upstream confirmation before downstream design, model, UI, or implementation details.

This loop is mandatory when a user asks about "new page vs existing workflow", "previous audit", "why did we do this", "Claude should challenge this but connect prior context", or any comparable continuation. A prompt can lack exact keywords and still be a continuation if the recovered anchors show a prior mainline.

If the loop finds no prior anchors, say that and then ask clarification. Do not invent history.

## Context Retrieval Before Clarification

Fuzzy input is not always missing information. For this user, fuzzy input often compresses prior decisions and repeated corrections.

Run bounded context retrieval before clarification when the prompt contains:

- "previously", "last time", "we already discussed", "I said many times";
- prior pages, ports, localhost routes, screenshots, browser tabs, or artifacts;
- audit, salvage, insertion, integration, old branch, or old project references;
- sample, generated image, UI, OCR/VLM, SKU, source/reference, or business workflow references;
- a correction such as "not a new page", "integrate into the existing surface", "direction is wrong".

Retrieval order:

1. Project `.workflow/current.yaml`, `task.yaml`, `open_threads.yaml`, `verification.yaml`, `thread_registry.yaml`.
2. `.workflow/memory_points.yaml` when present.
3. Local plans, contracts, receipts, reply logs, and docs likely tied to the named project or route.
4. Current browser or localhost state when the user references pages, screenshots, ports, or visible UI.
5. Maestro `search`, `wiki`, `kg`, `knowhow`, or workspace links when available.
6. Web search only when the user asks for external/latest information or local sources are insufficient.

Before asking clarification, cite the recovered anchors:

```text
Recovered anchors:
- <source>: proves <claim>
- <source>: proves <claim>
- <source>: does not prove <boundary>
```

Then ask at most 1-3 upstream questions. Do not ask downstream design questions before recovering the history that the user is pointing at.

## Root Diagnosis Before Questions

When prior anchors conflict with the current artifact, answer the conflict first. The main agent must not jump from "I found context" to generic clarification. It must synthesize a root diagnosis:

```text
Recovered mainline:
- <prior intended workflow or product chain>

Current observed artifact or proposal:
- <what the user is reacting to now>

Contradiction:
- <why this looks like drift, sidecar/new-page work, incomplete audit, wrong insertion point, missing original capability, or stale direction>

First confirmation:
- "Are you saying the next step is to return to <upstream insertion/audit/mainline>, not continue <downstream artifact>?"
```

This diagnosis comes before the 1-3 questions. If the first question is about a downstream field, visual variant, component, model, or implementation detail while the likely root issue is "the prior mainline was not integrated", the clarification failed.

For an existing-workflow insertion pattern, the first diagnostic question should be upstream:

```text
I recovered that the intended chain was <source/input> -> <existing product/workflow surface> -> <output/export/acceptance path>. Your current correction sounds like the audit/insertion analysis did not actually connect that chain to the existing surface, and the result feels like a new sidecar/workbench. Is that the main issue?
```

Only after that confirmation should the main agent ask about downstream fields, visual variants, sample details, model choices, or exact UI layout. Keep project-specific examples in case-study notes, not as global routing rules.

## Decision Consequence Disclosure

Clarification quality is measured by whether the user can understand the practical consequence without opening the plan document.

Before asking the user to approve any option, gate, plan, or visible slice that affects product shape, the main agent must state:

| Field | Meaning |
| --- | --- |
| `visible_change` | What page, route, panel, workflow, output, or artifact the user will see first. |
| `integration_mode` | Whether this is core integration, temporary sidecar/workbench, adapter, import/export path, or analysis-only. |
| `what_yes_authorizes` | The concrete work a "yes" allows. |
| `what_yes_does_not_authorize` | Claims or later gates that remain blocked. |
| `rejected_or_deferred_paths` | Which alternatives are dropped or postponed. |
| `rollback_or_reframe` | How to recover if the user says the result feels wrong. |

This is required even if the plan already contains those details. The user should not have to read every document to know that "Option A" means a new route, a sidecar, or a different workflow surface.

For example:

```text
Decision consequence:
- visible_change: add a temporary `<new route/workbench>` rather than changing `<existing surface>`.
- integration_mode: additive sidecar plus import/export draft, not core integration.
- yes authorizes: implement the named visible slice and produce inspectable evidence.
- yes does not authorize: full export readiness, publish/seller-ready claims, final UI acceptance, or generated-media quality acceptance.
- deferred: direct existing-surface integration and runtime adapter work.
Question: Is that temporary sidecar acceptable, or should the plan return to an existing-surface integration path first?
```

## Semantic Signals

Treat these meanings as signals even when the exact words are absent:

| User Meaning | Typical Routing |
| --- | --- |
| "Something feels wrong but I cannot name it." | Clarify/grill, not implementation |
| "Several attempts produced the wrong thing." | Blueprint -> salvage -> insertion plan |
| "I keep correcting the direction." | PM/FDE/UX/Data/Test synthesis plus open threads |
| "I mention prior pages/audits/samples." | Context retrieval before clarification |
| "The answer ignored earlier context." | Memory-point update plus rerun gate |
| "I cannot verify backend-only work." | Visible slice or browser/sample evidence gate |
| "This needs different viewpoints." | Codex App workers or Maestro delegate with receipts |
| "This is a lifecycle/project stage." | Maestro/Ralph only after gates are explicit |
| "This is a bounded independent check." | Worker or Maestro delegate |
| "I want it to continue without me for safe parts." | Semi-automatic worker/delegate loop, stop at human gates |
| "I am asking how to work, not asking for code." | Process coaching plus reusable workflow update |
| "This is small and acceptance is obvious." | Direct work with completion standard and verification |

## Maestro Decision

Use Maestro/Ralph when:

- there is a clear stage/lifecycle or role-routed analysis/write task;
- the current human gates are known;
- a delegate receipt or stage receipt can be produced;
- failure can return to `.workflow` without losing state.

Do not use Maestro/Ralph when:

- the product direction is fuzzy;
- UI/sample/generated-image acceptance is unresolved;
- the user is asking to clarify what they want;
- the task needs main-agent judgment more than execution throughput.

## Codex App Multi-Session Decision

Use Codex App worker sessions when:

- the task can be bounded to one question, file set, or verification claim;
- it can return a receipt with evidence and `does_not_prove`;
- context savings are meaningful;
- the main agent can inspect and accept/reject the receipt.

Do not use worker sessions when:

- the worker would decide product direction;
- the scope is not separable;
- the task is a human gate;
- the main agent cannot ingest the result.

## Claude Second-View Decision

Use Claude only as an optional second perspective in v2:

- plan critique;
- architecture/FDE review;
- PM/UX tradeoff analysis;
- "what did Codex miss?" review;
- second-view debate before updating formal docs.

Trigger Claude semantically, not permanently. Strong triggers include the user naming Claude/Opus, asking for "反驳", "收敛", "第二个大模型", "方案争论", or a high-value milestone where a second model can catch product/FDE/UX risk before expensive work.

Preferred route:

1. Use Maestro delegate when doctor plus a current smoke proves raw Claude output for the configured profile. This gives a bounded task, role/output history, and receipt-friendly integration.
2. Use direct `cc2` when Maestro is not proven, the user provides a known Claude session id, or a one-shot review is safer than changing durable config.
3. Use `cc2 --resume <session_id>` only when the next question depends on Claude's prior answer. Record resume reason, max turns, profile label, and close condition.

Do not require the user to configure Maestro role mappings before agents-init can help. Do not map review/brainstorm roles to Claude globally unless the user accepts that policy and a smoke test proves raw output. The main agent decides whether Claude is worth the quota and must ingest the result into `.workflow`, spec, knowhow, or formal docs.

## Orchestration Decision Fields

Every orchestration decision should answer:

```text
user_words:
recovered_state:
recovered_anchors:
root_diagnosis:
decision_consequence_disclosure:
semantic_signals:
current_gate:
recommended_route:
why_not_direct:
maestro_use:
codex_app_workers:
knowledge_lifecycle:
multi_perspective_review:
human_gates:
next_action:
does_not_prove:
```

If prior context changes the interpretation, record the correction in `open_threads` or `.workflow/memory_points.yaml` instead of relying on chat history.

## Multi-Perspective Review

Use `.workflow/templates/multi_perspective_review.yaml` or an equivalent compact note before execution when the task can drift, cross gates, or repeat prior failures.

Minimum views:

| View | Must Answer |
| --- | --- |
| PM | What user value, boundary, and acceptance would make this worth doing? |
| FDE | What data contracts, interfaces, failure states, and rollback/recovery matter? |
| UX/Visible Acceptance | What must the user see, compare, or approve beyond backend tests? |
| Workflow/Context Engineering | What prior anchors, memory points, receipts, and recovery state must be used? |
| Maestro/Codex App Orchestration | Which work should stay local, become a worker, use Maestro, use Claude, or stop at a gate? |
| Risk/Over-Engineering | What would be decorative process, premature automation, stale memory, or false proof? |

Each view must include evidence, risk or objection, and next action. If a view lacks evidence, mark it `insufficient_evidence` instead of filling it with plausible opinions.

The main agent synthesizes the views. Workers, Maestro, or Claude may supply perspectives, but they do not decide product direction or human-gated acceptance.

## Knowledge Lifecycle Loop

The main agent owns document maintenance. It must not hand the user a command list or keep appending summaries forever.

After every non-trivial analysis, receipt ingest, direction change, or verification step, decide:

| If The Information Is | Main-Agent Action |
| --- | --- |
| Current gate, next step, forbidden claim | overwrite `.workflow/current.yaml` |
| Current task queue or PM/FDE contract | update `.workflow/task.yaml` |
| Still unresolved or blocking | keep/update `open_threads.yaml` |
| Resolved, stale, or replaced | close or mark superseded in `open_threads.yaml` |
| Repeated user correction or changed direction | add/supersede atomic `memory_points.yaml` entry |
| Stable cross-task rule | promote to Maestro `spec` |
| Reusable workflow, session compact, receipt pattern, case lesson | promote to Maestro `knowhow` |
| Code insertion point, impact, dependency, old project salvage | run or request Maestro `kg index/sync/search/context` when available |
| Raw transcript, worker output, or model debate | store as receipt/archive and summarize active conclusions |

Before answering a context-referenced request, retrieve from active layers in this order: `.workflow`, memory points, Maestro search/spec/knowhow/wiki, KG/code search, browser/localhost evidence when relevant. The answer should cite anchors, not expose the whole document pile.

If `maestro search` cannot find a repeated lesson that `.workflow` knows, promote that lesson to spec or knowhow before calling the knowledge layer complete.

## If The User's Words Do Not Match Known Examples

Do not fall back to direct work. Use semantic reasoning:

1. Ask what outcome would prove success if the request is product/UI/sample/business-related.
2. Ask what must not happen again if the user references repeated failure.
3. Ask what can safely be delegated if the user wants multi-agent work.

Ask at most 1-3 questions, and record unanswered points in `open_threads`.
