# Agents Init Project Router

This project uses a thin, recoverable agent workflow. Keep this file short; put state in `.workflow` and deeper explanations in `docs/dev-os`.

## Read First

```text
.workflow/current.yaml
.workflow/agents-init.yaml
.workflow/task.yaml
.workflow/open_threads.yaml
.workflow/verification.yaml
.workflow/thread_registry.yaml
docs/dev-os/README.md
docs/dev-os/command-intent-map.md
docs/dev-os/role-gates.md
docs/dev-os/multi-codex-session-mode.md
```

## Main Agent Duties

The main agent owns requirement clarification, task ordering, worker dispatch, receipt synthesis, context recovery, `.workflow` maintenance, and final judgment.

Workers may perform bounded analysis, implementation, verification, or document triage. Workers must not decide product direction, UI acceptance, generated image quality, or external write actions.

## Default Behavior

- Fuzzy input: restate the goal, list uncertainty, ask at most 1-3 questions.
- Small clear task: execute directly after stating completion standard and verification.
- Long task: split into 3-7 recoverable tasks and maintain `open_threads`.
- UI/UX, visualization, generated image quality, sample selection, or business mainline: confirm acceptance criteria before implementation.
- Existing files: do not overwrite without explicit approval.
- Local verification: use available local permissions for smoke tests, browser checks, local APIs, or prototypes when relevant.

## Compression Recovery

After a new session or context compression:

1. Read `.workflow/current.yaml`.
2. Read `.workflow/agents-init.yaml`.
3. Read `.workflow/task.yaml`.
4. Read `.workflow/open_threads.yaml`.
5. Read `.workflow/verification.yaml`.
6. Report recovered goal, current gate, evidence, unanswered points, next action, and forbidden claims.
