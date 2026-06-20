# Multi-Model Shared Context

Use this reference when the user wants Codex, Claude, Maestro, Codex App sessions, or other CLI models to discuss one problem without losing context.

## Principle

Multi-model work is not "open several chats and hope." It is a main-agent controlled evidence loop:

1. Recover local context and memory points.
2. Define one bounded analysis task with allowed context and forbidden decisions.
3. Prefer a proven Maestro delegate route, then read raw delegate output.
4. Use direct `cc2` only as a local Claude profile/alias reference and fallback path.
5. Require a model review receipt.
6. Main agent synthesizes, accepts/rejects, and updates `.workflow` or Maestro knowledge.

Claude is never a second main agent. The main agent decides the question, context size, route, max turns, receipt acceptance, and close/resume policy.

## User-Visible Model Evidence

When the main agent cites Claude or another model, it must show evidence instead of only saying "the model concluded." The user-facing answer should include:

- the bounded task sent to the model, in one short sentence;
- the route and id, such as `maestro delegate` plus `exec_id`, or `cc2` plus `session_id`;
- `raw_output_ref` or the command used to read raw output;
- 2-5 key points from the model's raw output, clearly labeled as model output or summary;
- the main agent's synthesis: agree, disagree, unresolved, and why;
- what the model output proves and does not prove.

Do not hide a model review behind a receipt label. If the model produced useful reasoning, expose the useful reasoning. If raw output is empty, missing, stale, or only metadata, say the review is inconclusive and do not cite it as a conclusion.

## Async Communication Reality

There are three different "async" layers. Do not merge them mentally:

| Layer | Can Run In Background | Can Follow Up | Does It Auto-Push To Claude TUI? | Use |
| --- | --- | --- | --- | --- |
| Codex App multi-session | Yes, through Codex thread tools when available | Yes, send message to thread | No | durable role/MVP sessions and visible worker threads |
| Maestro delegate broker | Yes, `maestro delegate --async` | Yes, `maestro delegate message <id> ...` | No | background CLI-agent tasks with status/output/tail |
| Maestro agent-msg bus | Logs messages with `send/list/status` | It records messages | No | team activity log, conflict notes, coordination ledger |
| cc2 capturable CLI | Yes only as separate command/process | Yes with `--resume <session_id>` | No | Claude second opinions with JSON receipts |
| cc2 interactive TUI | User-driven continuous dialogue | Yes by typing in TUI | Not from this Codex session unless a terminal input/remote-control bridge exists | human-in-the-loop discussion |

So "Codex and Claude talk asynchronously" means the main agent relays context and receipts unless a working bridge is configured. It is hub-and-spoke, not peer-to-peer magic:

```text
user -> main Codex
main Codex -> context packet -> Claude/Codex worker/Maestro delegate
worker/model -> receipt -> main Codex
main Codex -> synthesis + .workflow update
```

The main agent may use Maestro `agent-msg` to log that a message was sent or a receipt was ingested, but `agent-msg` alone does not make Claude read it.

## Modes

| Mode | Trigger | Main-Agent Action |
| --- | --- | --- |
| `interactive_cli_continuous` | `cc2` or another TUI is used by the user for human-in-the-loop multi-turn work | Give the user a packet to paste and require a receipt back |
| `capturable_cli_one_shot` | `cc2 --safe-mode -p --model <model> --output-format json --no-session-persistence` is enough | Ask one bounded question, capture JSON, do not resume |
| `capturable_cli_continuous` | `cc2 --safe-mode -p --model <model> --output-format json` works and can resume with `--resume <session_id>` | Drive the model from the main agent/script, save JSON output, and ingest a receipt |
| `maestro_delegate` | `maestro delegate` returns usable output from the configured model/profile | Send one bounded analysis task, read `delegate output` or raw transcript, save delegate id/output as a receipt; prefer this when doctor proves raw output |
| `codex_app_one_shot` | Independent bounded analysis or verification | Register one-shot worker and ingest receipt |
| `codex_app_continuous` | Reusable role or MVP session should persist | Register continuous role with scope and conflict rules |
| `blocked` | Auth/model/tool control fails | Record failure and do not claim review happened |

## Claude Code `cc2` Modes

`cc2` has two useful modes. Keep them separate:

| Mode | Command Shape | Control | Use For | Evidence |
| --- | --- | --- | --- | --- |
| Interactive continuous | `cc2` then user types in the TUI | Human/user controls the conversation | fuzzy clarification, visible acceptance, exploratory debate | pasted receipt or transcript |
| Capturable one-shot | `cc2 --safe-mode -p "<prompt>" --model opus --output-format json --no-session-persistence` | main agent/script controls one turn | high-value second opinion or critique | JSON output |
| Capturable continuous | `cc2 --safe-mode -p "<prompt>" --model opus --output-format json --resume <session_id>` | main agent/script controls turns and captures JSON | structured second opinions, repeatable review, multi-model receipts | JSON output plus session id |

Use `--safe-mode` when the goal is a clean review receipt instead of tool execution. Use `--resume <session_id>` only for sustained context. Do not reuse one session across unrelated tasks unless the main agent intentionally wants that role memory.

`capturable_cli_continuous` is not the same as `maestro_delegate`. If Maestro's Claude delegate produces an empty output or an underlying model error, mark Maestro as inconclusive while still allowing direct `cc2` capture as a separate path.

## Preferred Route

Prefer `maestro_delegate` for Claude when it is proven on the current machine because it fits the workflow system: bounded task, role routing, history, `delegate output`, and receipt ingest.

`cc2` is the local Claude profile/alias reference and fallback, not the default lifecycle. On this machine it may show how the intended Claude account is selected, for example a wrapper that sets `CLAUDE_CONFIG_DIR` and accepts the moving model alias `opus`. Copy the idea, not the hardcoded path: discover the wrapper, inspect what it does, smoke the same profile through Maestro if possible, then record the actual model from raw output.

Use direct `cc2` when:

- Maestro delegate is not installed, not configured, or not raw-output-proven;
- the user explicitly wants to continue a known Claude session id;
- a quick one-shot review is safer than changing durable Maestro routing;
- Maestro was updated and doctor detects adapter/config drift.

Do not turn `cc2` into a giant chat dump. Even with `cc2`, pass a compact shared packet and ingest a receipt.

Do not send all recovered context to Claude by default. Send only the bounded task, the anchors needed to answer it, and the expected receipt format. If Claude needs more context, it asks for named missing anchors; the main agent decides whether to provide them.

## PM/FDE Routing Contract

PM view: Claude should enter the system when a second senior opinion changes the quality of the decision, not because "multi-model" sounds impressive. Good triggers are milestone plans, objections, architecture/FDE tradeoffs, UX/product acceptance framing, old-project insertion risk, or a user explicitly asking Claude to challenge a proposal. Routine search, implementation, formatting, and local verification stay with Codex/local tools.

FDE view: route choice is an interface contract:

| Surface | Meaning | Persistence | Receipt Requirement |
| --- | --- | --- | --- |
| `maestro_delegate` | Maestro spawns the configured tool for a bounded role/task | delegate history/output; role config may be durable | delegate id, raw output checked, tool/profile/model evidence |
| `cc2 --safe-mode -p` | direct capturable Claude one-shot | no durable policy if `--no-session-persistence` is used | JSON output, requested alias, actual model, cost/session when reported |
| `cc2 --resume <session_id>` | direct capturable continuation of a known Claude session | carries prior session context | resume reason, max turns, profile label, close condition |
| `cc2` TUI | human-driven interactive Claude | outside automatic main-agent control | user-pasted receipt/transcript |
| `cli-tools.json` | durable Maestro tool/role/profile policy | workspace or global config | config source, rollback note for writes, post-update smoke |

Config files and command parameters are not interchangeable:

- `cc2 --model opus` or `maestro delegate --to claude` is a one-call request.
- `<project>/.maestro/cli-tools.json` or `~/.maestro/cli-tools.json` is persistent routing policy.
- A wrapper such as `cc2` may set a local profile like `CLAUDE_CONFIG_DIR`; record the profile label without storing secrets.
- `--to claude` proves only that one command attempted Claude. It does not prove durable roles now use Claude.
- Maestro `completed` metadata is not success unless raw output is non-empty and task-relevant.

For this user, prefer explicit high-value Claude review over permanent role mapping until the user accepts a project-local policy. If the user later wants default review/brainstorm to use Claude, write a workspace `.maestro/cli-tools.json` after confirmation, not a silent global change.

## Model Selection Policy

Default important plan/architecture/product debate to the moving alias `opus`, not a hardcoded version string. The wrapper or local model config may map `opus` to the current Opus release. Use `sonnet` only when the user says to save quota, the task is routine, or `opus` fails and the user accepts fallback.

Natural-language overrides:

| User Says | Main-Agent Policy |
| --- | --- |
| "Claude use opus", "4.8", "important plan debate" | `requested_model_alias: opus` |
| "save quota", "cheap Claude", "sonnet is enough" | `requested_model_alias: sonnet` |
| "no Claude", "Codex only" | do not call `cc2`; record skipped multi-model review |
| "continuous Claude reviewer" | bounded `capturable_cli_continuous` with max turns and retire rule |
| "one-shot Claude", "second opinion only" | `capturable_cli_one_shot` with `--no-session-persistence` |

Do not claim "Opus 4.8" as the actual model unless the captured output identifies it. In receipts, record both the requested alias and the actual model reported by the tool.

For Maestro, store model aliases such as `opus` or `sonnet` in routing config when those are what the underlying CLI accepts. Store the resolved or observed concrete model only in receipts. Model releases change; route policy should not hardcode a dated concrete model unless a local tool requires it.

## Claude Profile Configuration

Users may have one Claude profile, multiple profiles, wrappers such as `cc2`, or an expired/default account. `agents-init` should guide configuration but not silently manage accounts.

Do not hardcode this user's `cc2` or `CLAUDE_CONFIG_DIR` as the universal route. Treat wrappers, profile directories, and aliases as discovered local configuration.

Discovery order for a new machine or project:

1. Inspect project policy in `.workflow/model_policy.yaml`.
2. Inspect available commands with `Get-Command cc2` and `Get-Command claude`.
3. Inspect Maestro config with `maestro config delegate show --json` when Maestro exists.
4. Smoke the exact route before relying on it.
5. Ask the user before writing any project-local or global route policy.

Success is route-specific:

| Route | Success Evidence |
| --- | --- |
| `cc2` wrapper | `cc2 --safe-mode -p ... --model opus --output-format json` exits 0 and raw JSON contains task output plus actual model evidence. |
| default `claude` | Same capturable smoke succeeds for the active default profile. |
| Maestro delegate | `maestro delegate output <execId>` or raw transcript contains the smoke token and task-relevant text. |

If `cc2` works but default `claude` fails, report that the default Claude profile is not the project route. If Maestro delegate fails while `cc2` works, report Maestro adapter/config failure, not "Claude unavailable."

Recommended declarative fields for a project or user policy:

```yaml
multi_model:
  claude:
    preferred_route: auto_discover_then_user_confirm
    fallback_route: capturable_cli_one_shot
    requested_model_alias: opus
    command: cc2
    profile_label: account2
    profile_switch_requires: explicit_user_confirmation
    env:
      CLAUDE_CONFIG_DIR: "<local-claude-profile-dir>"
    max_review_turns: 2
    require_receipt: true
```

Rules:

- `profile_label` is a human-readable handle, not a credential.
- `env` may point a tool at a local profile directory, but must not contain secrets in receipts.
- Account/profile switches require explicit user confirmation.
- If a profile expires, quota is exhausted, or auth fails, halt and report the failing profile; do not silently switch to another account.
- If Maestro or Claude updates change model aliases, run a small smoke and update the alias policy only after user confirmation.
- On another computer, rerun discovery and smoke. Do not assume the same wrapper name, profile directory, or Maestro adapter state exists.

## Quota And Context Policy

Claude budget is scarce. Do not route routine execution, file editing, broad grep, or simple implementation to Claude by default.

Use Claude for:

- high-leverage architecture/PM/FDE/UX critique;
- second opinion on ambiguous product direction;
- adversarial review of plans before expensive implementation;
- visual/sample/generated-image acceptance framing, while leaving final acceptance to the user.

Do not build a permanent Claude role network in the first v2 pass. Use Claude as a bounded second-view analyst: one compact context packet or Maestro delegate task, one second-view analysis or objection, then main Codex synthesizes and updates the formal state.

Prefer this order:

1. `maestro_delegate` with raw output proven for the configured Claude profile/model alias.
2. `capturable_cli_one_shot` with `--model opus` for one bounded high-value question when Maestro is inconclusive.
3. `capturable_cli_continuous` with `--model opus` only when the follow-up requires Claude's prior answer or role memory.
4. `interactive_cli_continuous` when the user wants to personally explore with Claude.

Do not keep resuming a Claude session just because it exists. Every resume carries prior context and can increase token use. If the next prompt can stand alone with a short packet, start a fresh one-shot instead.

For milestone-level work where the user mentions Claude, second model, "反驳", "收敛", or an important plan debate, open a bounded review cycle:

- recover anchors first;
- create one compact packet or delegate task;
- choose `maestro_delegate` if raw-output-proven, otherwise `cc2`;
- set `max_review_turns` before the first call;
- stop when a receipt is accepted, the gate changes, or quota/model risk appears.

If a model starts broad repository exploration when asked for a design review, cancel or narrow the task. A second model is a bounded reviewer, not a second main agent.

Read-only review can still include file reading. The main agent should name the allowed files, directories, or knowledge surfaces in the packet. The model may read those sources and produce analysis, but it must not write files, change config, expand the search radius, or decide product direction. If it needs more context, it should list the missing anchors for the main agent.

## Closing And Retirement

For interactive TUI sessions, close in Claude with `/exit` when the human-driven discussion is done.

For capturable sessions, "close" means:

- ingest the receipt;
- save only the summary, decision, and evidence to `.workflow`, Maestro spec/knowhow, or memory points;
- mark the session retired in `thread_registry.yaml`;
- stop using `--resume <session_id>`.

Start a fresh session when:

- the task changes;
- the role changes;
- the user changes direction;
- the session would need a long recap to stay aligned;
- the next turn is execution rather than analysis.

Keep a capturable Claude session alive only when there is an explicit bounded reason, such as "Claude reviewer for one named gate only", and retire it after the receipt is accepted or rejected.

## Session ID Lifecycle

Capture Claude session ids only when they are useful for continuity:

- record a session id from `cc2` JSON output, user-provided screenshots/transcripts, or environment variables such as `CLAUDE_CODE_SESSION_ID` and `CLAUDE_CODE_CHILD_SESSION` when visible;
- store it in the model receipt or `thread_registry.yaml` with `profile_label`, `scope`, `created_at`, and `resume_count`;
- use `--resume <session_id>` only with a written `resume_reason` and max-turn policy;
- retire the session when the receipt is ingested, the gate changes, the user changes direction, or quota/model risk appears;
- do not resume an old Claude session when a fresh compact packet can answer the question.

## Periodic Review Cycle

"Periodic" or "continuous" review is not an infinite model chat. Configure:

- `cycle_scope`: the gate or artifact under review;
- `requested_model_alias`: usually `opus`;
- `max_review_turns`: default 2 unless the user raises it;
- `resume_policy`: resume only when the next question depends on the prior Claude answer;
- `close_condition`: receipt accepted, gate changes, user changes direction, or quota concern appears.

If the next review can be asked with a compact fresh packet, start a new one-shot instead of resuming the old session.

## Packet Contract

Use `.workflow/templates/multi_model_context_packet.md`.

The packet must include:

- project and current gate;
- recovered anchors with `proves` and `does_not_prove`;
- the user's pain point or decision pressure;
- one bounded question for the model;
- forbidden decisions and human gates;
- expected receipt format.

## Receipt Contract

Use `.workflow/templates/model_review_receipt.yaml`.

The receipt must include:

- model/tool identity;
- execution mode;
- context packet id;
- raw output reference and whether raw output was checked;
- exit code and error summary;
- answer and reasoning summary;
- evidence used;
- assumptions;
- `proves` and `does_not_prove`;
- risks;
- recommended next step.

No receipt means no evidence. A useful conversation still has to be converted into a receipt before the main agent can rely on it.

## Common Failure

If `cc2` interactive opens but `cc2 -p` fails authentication, the correct route is `interactive_cli_continuous`, not `maestro_delegate` and not automatic Claude. If `cc2 --safe-mode -p --model claude-sonnet-4-6 --output-format json` works, prefer `capturable_cli_one_shot` for isolated reviews and `capturable_cli_continuous` only for bounded multi-turn analysis. If Maestro delegate returns empty output, record the delegate id and mark the review inconclusive.
If `cc2 --safe-mode -p --model opus --output-format json` fails but `sonnet` works, record the fallback explicitly and do not pretend the Opus review happened.
If Maestro delegate works only after local package patches, record it as `proven_with_local_patch` and run doctor after every Maestro update. Do not present the patch as portable skill behavior.
