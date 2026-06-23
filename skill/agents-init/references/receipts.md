# Receipts

Use this reference when accepting worker, delegate, verification, handoff, UI, image, or sample outputs.

## Required Receipt Fields

Every worker/delegate receipt needs:

- task id;
- worker/delegate id;
- scope;
- files read;
- files changed if any;
- commands run;
- artifacts;
- evidence;
- decisions locked/proposed;
- open threads;
- `proves`;
- `does_not_prove`;
- risks;
- next recommended step.

## Accept A Receipt Only If

- the task stayed inside scope;
- evidence exists and is inspectable;
- the worker did not decide product direction;
- `proves` and `does_not_prove` are both present;
- human-gated claims are not marked accepted without user-visible evidence and user confirmation;
- `.workflow` updates are clear.

By default, `ingest-receipt.ps1` checks receipt shape and false-acceptance risks only. With an explicit main-agent decision, `ingest-receipt.ps1 -Apply -Decision accepted|rejected` can write that decision back into workflow state by appending verification evidence and updating matching thread/delegate registry records.

Applying a receipt does not judge product quality, UI taste, sample quality, or whether evidence is sufficient for the user's intent. The main agent must inspect artifacts first, then accept, reject, or request revision. `-Apply` records the main agent's decision; it does not replace the decision.

Use `.workflow/templates/workflow_closeout_receipt.yaml` or `closeout-workflow.ps1` after a route, gate, direction, handoff, promotion, or archive cleanup changes the active workflow head. A closeout receipt updates `authority_index.yaml`, appends verification evidence, and refreshes the session-recovery brief. It is not product acceptance and does not prove Maestro promotion unless the promoted artifact is listed with separate evidence.

For model or delegate receipts, inspect raw output, not only tool metadata. Accept the receipt only when:

- `raw_output_checked` is true;
- `raw_output_ref` points to captured JSON, terminal output, delegate output, or transcript;
- `exit_code` and any `stderr_or_error_summary` are recorded;
- `actual_model_verified_from_output` is true when a model identity is claimed;
- empty output, auth errors, stale streams, or model-mapping errors are marked `failed` or `inconclusive`.

For Maestro delegates, meta files may show the requested model or exit status while raw jsonl/output contains the real error. Raw output decides acceptance.

## Reject Or Return If

- it says "done" without evidence;
- it uses backend tests to claim UI/generated-image/sample acceptance;
- it edits outside scope;
- it skips open questions;
- it produces a plan but no next gate;
- it cannot distinguish proof from non-proof.

## Receipt Types

Use the project templates:

```text
.workflow/templates/worker_receipt.yaml
.workflow/templates/delegate_receipt.yaml
.workflow/templates/handoff_receipt.yaml
.workflow/templates/verification_receipt.yaml
.workflow/templates/ux_issue.yaml
.workflow/templates/sample_decision.yaml
.workflow/templates/image_quality_review.yaml
.workflow/templates/model_review_receipt.yaml
.workflow/templates/workflow_closeout_receipt.yaml
```
