# Agents Init

This folder explains how this project should be developed with the user's reusable agent workflow.

## Start Prompts

Use natural language. Exact commands are optional.

```text
$agents-init recover 当前项目，告诉我 goal、gate、active task、open threads、证据和下一步。
```

```text
我这个需求很模糊。先复述你的理解，列出不确定点，最多问我 1-3 个问题，再落成 task card。
```

```text
这是长任务。先用 PM/FDE/UX/Data/Test 多视角拆成 3-7 个可恢复子任务，不要直接实现。
```

```text
这是旧项目/旧 worktree 二开失败。先做 blueprint、salvage、insertion plan，别直接写代码。
```

```text
这是小目标，不需要 Maestro。直接做，但先说明完成标准和验证方式。
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
$agents-init save-state
```

## Non-Overwrite Policy

Existing project files are user work. Do not overwrite them automatically. For existing projects, add `.workflow` sidecar files first, then patch `AGENTS.md` only after reading it and confirming the intended router entry.
