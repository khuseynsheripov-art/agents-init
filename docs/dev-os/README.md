# Agents Init

This folder explains how this project should be developed with the user's reusable agent workflow.

## Start Prompts

Use natural language. Exact commands are optional.

```text
$agents-init menu
```

```text
agents-init help. Tell me what you can do for this project.
```

```text
$agents-init recover this project and report goal, gate, active task, open threads, evidence, and next step.
```

```text
This requirement is fuzzy. Restate your understanding, list uncertainty, ask at most 1-3 questions, then make a task card.
```

```text
This is a long task. Use PM/FDE/UX/Data/Test views and split it into 3-7 recoverable tasks before implementation.
```

```text
This old project/worktree failed. Do blueprint, salvage, and insertion plan before writing code.
```

```text
Update agents-init, then upgrade this project workflow.
```

```text
This is a small clear task. Do it directly, but first state completion standard and verification.
```

## Operating Model

The main agent is the orchestrator. It clarifies requirements, chooses gates, dispatches bounded workers, reads receipts, updates `.workflow`, and decides whether evidence proves the claim.

Workers and Maestro delegates are evidence producers. They do not decide product direction or human acceptance gates.

## Command Menu

```text
$agents-init menu
$agents-init recover
$agents-init doctor
$agents-init validate
$agents-init pressure-test
$agents-init grill
$agents-init brainstorm
$agents-init blueprint
$agents-init plan
$agents-init register-main
$agents-init dispatch-worker
$agents-init ingest-receipt
$agents-init route-maestro
$agents-init self-update
$agents-init save-state
```

## Non-Overwrite Policy

Existing project files are user work. Do not overwrite them automatically. For existing projects, add `.workflow` sidecar files first, then patch `AGENTS.md` only after reading it and confirming the intended router entry.
