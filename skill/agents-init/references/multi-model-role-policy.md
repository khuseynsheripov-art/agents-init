# Multi-Model Role Policy

Use this reference when routing analysis, review, implementation, or research across Codex native subagents, Codex App workers, Maestro delegate, or external CLI tools.

## Role Policy

| Role | Good For | Proof Required |
| --- | --- | --- |
| PM | user value, acceptance, scope | task card and open questions |
| FDE | data contracts, interfaces, failure states | file/module evidence and rollback plan |
| UX/UI | visible workflow, interaction, screenshots | browser/screenshot/user gate |
| Data/Research | samples, source facts, matrices | source list and boundary statement |
| QA/Verifier | tests, smoke checks, regression risks | commands, outputs, proves/does_not_prove |
| Implementer | bounded code changes | changed files, tests, verification receipt |
| Reviewer | critique and risk finding | findings with file/evidence references |

## Tool Routing

- Use native Codex subagents for bounded parallel local analysis/verification.
- Use Codex App worker threads when the user wants visible multi-session handoff or long worker history.
- Use Maestro delegate for role-routed CLI tasks when configured.
- Use interactive CLI sessions such as `cc2` through a shared context packet plus a pasted receipt when the user drives the TUI.
- Use capturable CLI one-shot sessions such as `cc2 --safe-mode -p ... --output-format json --no-session-persistence` for most bounded Claude reviews.
- Use capturable CLI continuous sessions such as `cc2 --safe-mode -p ... --output-format json --resume <session_id>` only when the next turn needs Claude's prior context.
- Use Maestro spec/knowhow for durable constraints and reusable lessons.

## Current Default

If only Codex is configured, still use roles as perspectives. Do not pretend multi-model evidence exists.

## Execution Modes

| Mode | Use When | Counts As Multi-Model Proof? | Required Artifact |
| --- | --- | --- | --- |
| `codex_native` | Local subagents can answer bounded questions | No, unless a non-Codex model also ran | worker receipt |
| `codex_app_session` | The user wants visible one-shot or continuous Codex App role sessions | No | worker receipt and thread registry entry |
| `maestro_delegate` | Maestro delegate returns usable output for a configured non-Codex tool | Yes, for that tool only | delegate receipt |
| `interactive_cli_continuous` | A tool such as `cc2` opens a working interactive TUI and the user drives the conversation | Yes only after the user/model returns a receipt | context packet plus model review receipt |
| `capturable_cli_one_shot` | A tool such as `cc2` can return JSON for one bounded question | Yes | JSON output plus model review receipt |
| `capturable_cli_continuous` | A tool such as `cc2` can return JSON and resume by session id | Yes | JSON output plus model review receipt |
| `unavailable` | Auth, model mapping, terminal backend, or tool control fails | No | failure note in verification |

For review tasks, also state `review_scope`:

| Review Scope | Meaning |
| --- | --- |
| `read_only` | The model may read only the context files explicitly allowed by the main agent and may only return analysis. |
| `propose_changes` | The model may suggest edits or patches, but the main agent decides whether to apply them. |
| `implement` | The model is asked to write/change files inside an explicitly bounded scope. |

Read-only second-model review is allowed and often useful. It is not the same as free exploration: the main agent names allowed files or context surfaces, the model returns a receipt, and the main agent remains the router and final judge.

The main agent must state which mode actually ran. If `cc2` interactive opens but `cc2 -p` fails authentication, use `interactive_cli_continuous`; do not claim automatic Claude review. If `cc2 --safe-mode -p --model opus --output-format json` works, it is the default capturable Claude route for important plan/architecture/product debate. Use `sonnet` only for quota-saving or explicit fallback. Use `--resume <session_id>` sparingly because it carries prior context and consumes more quota. If Maestro delegate starts but returns empty output or its raw jsonl contains a model error, record Maestro as failed or inconclusive.

## Claude Quota Rules

- Use Claude for analysis, architecture, critique, ambiguous direction, and plan review.
- Do not use Claude for routine execution, broad code search, or implementation unless the user explicitly chooses it.
- Prefer one-shot review with a compact packet.
- Resume a Claude session only when the next question depends on its prior answer.
- Retire a Claude session after receipt ingest; keep only the distilled memory point or spec/knowhow entry.

## Shared Context Packet

For manual or automatic multi-model review, generate a packet before asking another model:

```text
Purpose:
Current project and gate:
Recovered anchors:
User pain / target outcome:
Bounded question for this model:
What must not be decided by this model:
Expected receipt fields:
```

The packet is the synchronization boundary. Do not ask another model from chat memory alone.

## Boundaries

The main agent may use other agents to collect evidence, but final product direction remains with the main agent plus user gate.

For visual/product/sample decisions, require visible artifacts and user confirmation regardless of model/tool.
