# Context Hygiene And Evidence Exhaustion

Use this reference for evidence-heavy branch work, context compression, system-error recovery, or claims that a codebase/document area has been exhaustively inspected.

This is a low-frequency high-risk guardrail. Do not turn every task into an evidence-exhaustion ceremony. Use it when missing evidence could change direction, acceptance, safety, or cross-branch contracts.

## Core Rule

Keep raw evidence in files, receipts, indexes, or artifacts. Keep model context bounded to digests, slices, and the current decision head.

rg alone is not evidence exhaustion. A text search can support `partial_continue`, but not a claim that no evidence exists unless the method also records scope, methods, negative searches, files opened, and not-read gaps.

## Trigger Signals

Run an evidence exhaustion check when:

- a branch was compressed and resumed with uncertainty about what was actually read;
- a worker hit `systemError`, repeated interruption, or context-window pressure;
- a receipt claims "no evidence found" or "fully reviewed";
- there are many artifacts/logs/transcripts and only search snippets were inspected;
- the next step would rely on absence of evidence;
- external receipt, Web research, or model review conflicts with local evidence.

## Required Fields

Use `.workflow/templates/evidence_exhaustion_check.yaml` when this guardrail is needed.

Minimum fields:

- `scope`: exact files, directories, receipts, threads, or artifacts considered.
- `methods`: search, file-open, AST/parser, test, browser, log, registry, or receipt inspection methods.
- `positive_evidence`: what was found and inspected.
- `negative_searches`: searches that returned nothing or nothing relevant.
- `not_read_open_gap`: important areas not opened, inaccessible, too large, binary, generated, or intentionally deferred.
- `excluded_noise`: runtime/cache/log noise excluded from model context.
- `confidence`: exhaustive_for_scope, partial_continue, inconclusive, or blocked.
- `does_not_prove`: claims still forbidden.

## Branch Compression Pattern

For a branch at risk of losing context:

1. Write an evidence digest before compression.
2. Put raw paths and large outputs in artifacts, not chat memory.
3. Record not-read gaps explicitly.
4. On resume, recover the digest, then open only the slices needed for the next decision.
5. If a gap affects direction or acceptance, return to main agent instead of filling it with inference.

Use `.workflow/templates/evidence_digest.yaml` for compact handoff across branch sessions.

## What Not To Generalize

Do not require evidence exhaustion for:

- small direct tasks with obvious verification;
- normal `recover` or `validate` calls;
- every worker receipt;
- every `rg` search;
- routine documentation updates.

Do not promote project-specific matrices, platform rules, or named branch taxonomies into agents-init. Promote only the invariant: absence claims need method, scope, negative searches, and not-read gap disclosure.
