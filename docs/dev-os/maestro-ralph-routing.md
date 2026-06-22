# Maestro And Ralph Routing

Maestro and Ralph are execution aids. The main agent remains the orchestrator.

| Route | Use When | Do Not Use When | Required Output |
| --- | --- | --- | --- |
| Direct | Small clear task, low ambiguity | Product/UI/sample uncertainty | Verification note |
| Grill | Requirement fuzzy, user unsure | Task already has acceptance | Clarified task card |
| Brainstorm | Need PM/FDE/UX/Data/Test perspectives | Pure mechanical edit | Synthesis and open threads |
| Blueprint | Chaotic feature or second-development | Scope already clear and tiny | Requirement/module/risk/acceptance map |
| Worker | Independent bounded task | Shared product direction decision | Worker receipt |
| Maestro delegate | Clear role-routed analysis/write task | Human gate unresolved | Delegate receipt |
| Ralph | Clear lifecycle with gates | Fuzzy UI/sample/generated-image quality | Stage receipt and pause points |

## Maestro Delegate

Use `--role` when possible:

```powershell
maestro delegate "analyze the canvas extension points" --role analyze --mode analysis --cd "<project>" --async
maestro delegate status <execId>
maestro delegate output <execId>
maestro delegate message <execId> "additional bounded context"
```

Every delegate result must be summarized into `.workflow/templates/delegate_receipt.yaml`.

## Claude And Multi-Model Routing

Use direct `cc2` and Maestro delegate as separate routes:

- `cc2 --safe-mode -p "<packet>" --model opus --output-format json --no-session-persistence` is the preferred capturable Claude route for one bounded high-value review.
- `cc2 --safe-mode -p "<follow-up>" --model opus --output-format json --resume <session_id>` is only for a follow-up that depends on Claude's previous answer.
- `maestro delegate --to claude ...` is a Maestro adapter smoke, not proof that durable roles route to Claude.
- `.maestro/cli-tools.json` or `~/.maestro/cli-tools.json` is durable role config; command flags such as `--to claude` or `--model opus` are one-call requests.

Do not claim multi-model review until raw output is inspected. A Maestro meta/status summary is not enough; `maestro delegate output <execId>` or raw jsonl/transcript must contain non-empty usable content. Empty output, stale streams, auth errors, or unavailable-model errors make the result failed or inconclusive.

For Claude receipts, record requested alias, actual model from output, session id, raw output reference, exit code, error summary, proves, does_not_prove, and main-agent ingest decision.

## Windows / Codex Limits

- Codex hooks are not currently reliable on Windows in the local Maestro guide.
- Terminal backend should not be assumed in normal PowerShell.
- Delegate is useful, but `.workflow` remains the recovery source.

## Failure Return

If Maestro/Ralph fails, drifts, or asks for input:

1. Stop the chain.
2. Record failure in `verification.yaml`.
3. Add unresolved decision to `open_threads.yaml`.
4. Return to main agent for routing.

## Human Gate Rule

Ralph cannot auto-accept UI, samples, generated images, export readiness, seller-ready claims, or external writes.
