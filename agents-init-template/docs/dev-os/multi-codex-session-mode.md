# Multi-Codex Session Mode

Use this mode when one main thread should coordinate bounded worker threads to save context.

## Main Thread

The main thread owns product direction and `.workflow`.

Before creating or messaging a worker:

1. Define one bounded question.
2. Define allowed files or read-only scope.
3. Attach the worker receipt contract.
4. Register the worker in `.workflow/thread_registry.yaml`.

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

The main agent must read the receipt, inspect artifacts if needed, update `.workflow`, and decide whether the next gate can proceed or must return to the user.
