# Main Worktree Orchestration

Use this reference when a project needs a main agent to coordinate multiple worktrees, Codex App branch sessions, or module branches after the project has been understood enough to split responsibility.

## Compatibility Rule

The default entry remains agents-init and natural language. agents-init main is optional; it is a shortcut for explicitly entering or resuming main orchestration, not a required habit change.

Main orchestration is state-driven, not keyword-driven. The main agent must recover `.workflow`, understand the user's goal, identify object/module boundaries, and disclose consequences before proposing worktrees or branch sessions.

Do not create worktrees blindly. Worktree creation changes project topology and must be preceded by:

- recovered goal and active gate;
- module/object boundary hypothesis;
- branch responsibility and write scope;
- conflict set and rollback/recovery point;
- visible consequence for the user;
- what creation proves and does not prove.

If a project already has its own orchestrator rules, AGENTS.md, or `.workflow`, agents-init adapts to that control plane. It must not replace the active main agent or override local project rules without an explicit handoff.

## Role Model

Generic roles:

- user/executive: confirms direction, gates, and acceptance.
- main agent/orchestrator: clarifies goals, splits branches, sends task packets, ingests results, maintains `.workflow`, and makes final judgments.
- branch actor: executes one bounded task in one worktree or session and returns evidence.

Local projects may rename these roles. Ozon is a case study, not a rule template. Do not copy fixed B/S/C lanes, ERP-specific task ids, platform rules, or business acceptance claims into generic agents-init behavior.

## Packet Lifecycle

Generic lifecycle:

```text
task_packet -> branch_plan -> completion_notice -> data_packet -> chairman_brief -> parked_waiting_next_packet
```

Meaning:

- `task_packet`: main-agent authorization for one bounded branch task. It is not evidence.
- `branch_plan`: branch actor's scope confirmation before deep work. It is not completion.
- `completion_notice`: branch actor says the bounded task ended, partially ended, or blocked. completion_notice is not acceptance.
- `data_packet`: structured evidence or contract payload returned to the orchestrator. It is input evidence, not final judgment.
- `chairman_brief`: main-agent synthesis for the user/executive after ingesting receipts and packets.
- `parked_waiting_next_packet`: normal resting state after a branch task closes; it is not failure.

Only the main agent accepts, rejects, or requests revision after inspecting receipts/artifacts. Branch actors must not self-accept their data packets or start the next task without a new packet.

## When To Enter This Mode

Use main/worktree orchestration when:

- the project has multiple separable modules or workstreams;
- work requires isolated write scopes or parallel verification surfaces;
- branch context is valuable enough to preserve in a worktree or durable Codex App session;
- cross-branch data contracts or receipts must be preserved outside chat memory.

Do not use it when:

- the task is small and clear;
- the real task is clarification or product direction;
- the branch split is based only on a command word such as "main" or "worktree";
- a human gate is unresolved for UI, sample, generated image, business readiness, or external writes.

## Main-Agent Loop

Before dispatch:

1. Recover `.workflow` and local rules.
2. Restate the user's goal and list uncertainty.
3. Identify candidate module/object boundaries.
4. Decide direct vs worker vs Maestro vs main/worktree orchestration.
5. If worktrees are proposed, disclose path/branch/scope/conflicts and what remains unproven.
6. Create or update task packets only after the gate is clear.

After branch return:

1. Read completion notice, receipt, and data packet.
2. Check scope, evidence, proof boundaries, and forbidden claims.
3. Accept, reject, or request revision as main agent judgment.
4. Update `thread_registry.yaml`, `verification.yaml`, `open_threads.yaml`, and `authority_index.yaml`.
5. Write a `chairman_brief` with 1-3 upstream questions when user confirmation is needed.
6. Park the branch as `parked_waiting_next_packet` or archive/retire it.

## False Proofs

Never claim these as proof:

- created worktree;
- registered main;
- started worker;
- route-intent recommendation;
- `valid=true`;
- completion notice without receipt/data packet;
- data packet without main-agent ingest;
- chairman brief without artifact inspection;
- branch parked state as product completion.

All live product, UI, sample, image, seller-ready, external-write, and business acceptance claims still need their own evidence and human gate.
