# Multi-Codex Session Mode

Use this mode when one main thread should coordinate bounded worker threads to save context.

Default worker lifecycle is disposable: create or message one worker, get one receipt, ingest it, then archive/close the worker when tools allow. Durable workers are optional and only for repeated bounded work in one domain.

## Main Thread

The main thread owns product direction and `.workflow`.

Before creating or messaging a worker:

1. Define one bounded question.
2. Define allowed files or read-only scope.
3. Attach the worker receipt contract.
4. Register the worker in `.workflow/thread_registry.yaml`.
5. If the main thread id is known, register it. If unknown, keep `current` and ask the user only when cross-thread read/send requires a real id.

Use `make-worker-prompt.ps1` to generate the worker prompt when possible. Store dispatch prompts under `.workflow/dispatch/` for traceability when the task is not private.

## Worker Thread Prompt

```text
You are a worker for this project. Do only this bounded task:

Task:
<task>

Scope:
<files/area>

Rules:
- Do not decide product direction.
- Do not overwrite unrelated work.
- Return a worker receipt using .workflow/templates/worker_receipt.yaml.
- Include evidence, risks, open questions, proves, does_not_prove, and next.
```

## After Worker Returns

The main agent must read the receipt, inspect artifacts if needed, accept or reject the receipt, update `.workflow`, and decide whether the next gate can proceed or must return to the user.

## Waiting Policy

No fixed-interval recall. After dispatching a bounded worker, wait for the worker receipt instead of nudging or summarizing on a timer. A status note is useful only when the user asks for status, a worker deadline expires, a tool reports completion/failure/interruption, a human gate is reached, or active workers may conflict.

If the worker is still running, say that plainly and keep waiting. Do not count started work as evidence.

If a new main session takes over, it must read `.workflow/thread_registry.yaml`, mark old main ids as historical/superseded when appropriate, and register itself as active if a real id is available.

Use `ingest-receipt.ps1` as a shape check. Passing the script means the receipt is eligible for main-agent review; it does not mean the output is accepted.

After the main agent inspects artifacts and decides, apply the decision explicitly:

```powershell
# short form: ingest-receipt.ps1 -Apply -Decision accepted|rejected
powershell -NoProfile -ExecutionPolicy Bypass -File "<skill>\scripts\ingest-receipt.ps1" -ProjectPath "<project>" -ReceiptPath "<receipt.yaml>" -Apply -Decision accepted|rejected -Json
powershell -NoProfile -ExecutionPolicy Bypass -File "<skill>\scripts\init-agents.ps1" -ProjectPath "<project>" -Mode ingest-receipt -ReceiptPath "<receipt.yaml>" -ApplyReceipt -ReceiptDecision accepted|rejected
```

Applying a receipt appends verification evidence and updates the matching thread registry record. It does not replace artifact inspection or human-gated acceptance.
