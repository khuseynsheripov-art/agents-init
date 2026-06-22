# Agents Init

This folder explains how the project should be developed with the user's reusable agent workflow.

## How To Start

Use one of these natural-language prompts:

```text
按 Agents Init 恢复当前项目，告诉我 current gate、active task、open threads、证据和下一步。
```

```text
这是模糊需求。先复述目标，最多问我 3 个确认问题，再落成 task card。
```

```text
这是长任务。先按 PM/FDE/UX/Data/Test 多视角拆解成 3-7 个可恢复子任务，不要直接实现。
```

```text
这是小目标，不需要 Maestro。直接做，但先说明完成标准和验证方式。
```

## Operating Model

The main agent is the orchestrator. It clarifies requirements, picks the gate, dispatches bounded workers, reads receipts, updates `.workflow`, and decides whether evidence proves the claim.

Use workers or separate Codex threads for independent analysis, implementation, verification, or document triage. Each worker must return `.workflow/templates/worker_receipt.yaml`.

## Non-Overwrite Policy

Existing project files are user work. Do not overwrite them automatically. For existing projects, add `.workflow` sidecar files first, then propose small `AGENTS.md` patches after reading the current rules.
