# Usage Playbook

Use this reference when the user asks "how do I use this day to day?"

## Natural Language First

The user should not memorize commands. The main agent maps natural language to one of these paths.

| User Says | Main Agent Does |
| --- | --- |
| "先联系上下文，看我之前说过什么" | recover + bounded context search + cite anchors |
| "找 Claude 帮我反驳这个方案" | create compact packet, run `cc2` one-shot, ingest model receipt |
| "Claude 持续当架构 reviewer" | create/record bounded `cc2` continuous session with retire rule |
| "开几个 Codex 会话分别看" | create/use Codex App one-shot or continuous role sessions |
| "异步跑一下分析" | use Maestro delegate `--async` if route works, otherwise Codex worker or direct `cc2` one-shot |
| "记录给团队/角色" | use Maestro `msg` as coordination ledger |
| "这个规则以后都要记住" | memory point now, promote stable rule to Maestro spec/knowhow |
| "不要一直堆文档/文档怎么维护" | run knowledge lifecycle: update, close, supersede, promote, index, archive |
| "旧项目怎么融入" | recover + KG/search/code anchors + insertion plan before implementation |

## Recommended Daily Pattern

1. Main Codex recovers `.workflow`.
2. Main Codex retrieves prior anchors before clarification.
3. Main Codex checks whether the user is continuing/correcting prior work, generates competing hypotheses, and states the root diagnosis when history and current artifact conflict.
4. Main Codex decides whether the task is clarification, plan, implementation, verification, or human acceptance.
5. For high-value plan debate, ask Claude with one compact packet after the anchors are recovered.
6. For implementation and local testing, use Codex/local tools.
7. For parallel Codex work, use Codex App sessions with receipts.
8. For lifecycle/logging/knowledge, use Maestro only where its route is proven.
9. Main Codex ingests receipts and updates `.workflow`.
10. Main Codex performs knowledge maintenance: close stale threads, supersede old memory, promote stable lessons to spec/knowhow, sync KG/search when code context matters, and archive raw transcripts.

## Document Maintenance Pattern

The user should not decide where every note lives. The main agent should classify information:

```text
current truth -> overwrite current/task
unresolved issue -> open_threads
repeated correction -> memory_points
stable constraint -> Maestro spec
reusable recipe/case lesson -> Maestro knowhow
code impact/insertion -> Maestro KG/search
raw transcript/output -> receipt/archive
obsolete direction -> superseded, not active
```

When the user says a task "lost context", "I said this before", "this direction changed", or "documents are piling up", the main agent should maintain the layers immediately before proposing more work.

## Keep V2 Simple

For the next iteration, do not make the user configure a full multi-model role network.

The practical target is:

```text
main Codex = orchestrator, context recovery, clarification, dispatch, final judgment
Claude = optional second-view analyst for plans, architecture, PM/FDE/UX tradeoffs, and objections
Codex App sessions = bounded workers or durable Codex role sessions
Maestro = lifecycle/knowledge/message ledger, and delegate only when proven
```

Do not register Claude as a permanent role by default. Ask Claude only when the main agent decides a second perspective is worth the quota.

Keep the entry light and the evidence strong. The user should experience agents-init as:

```text
recover mainline -> diagnose drift -> disclose consequence -> ask the smallest upstream question -> route only the needed tools
```

The command menu, templates, Maestro surfaces, and Claude modes are support machinery. They should stay behind the main-agent loop unless the current gate actually needs them.

## Claude Budget Pattern

Preferred when Maestro Claude is proven by current doctor/smoke:

```powershell
maestro delegate --to claude --mode analysis --cd "<project>" "<compact packet>"
maestro delegate output <execId>
```

Fallback/direct one-shot:

```powershell
cc2 --safe-mode -p "<compact packet>" --model opus --output-format json --no-session-persistence
```

Use resume only when needed:

```powershell
cc2 --safe-mode -p "<follow-up>" --model opus --output-format json --resume <session_id>
```

Retire after ingest. Do not keep resuming for unrelated tasks.

Use `sonnet` only when the user asks to save quota or Opus is unavailable and the fallback is explicitly recorded.

Cross-task resume is a failure mode. If the next question can be answered with a compact fresh packet, start a new one-shot. Reuse `--resume <session_id>` only when the next question depends on the previous Claude answer, and record `resume_reason`, `max_review_turns`, and `close_after_ingest`.

When the user mentions Claude together with "previously", "前文", "方案", "反驳", or "收敛", the route is not "call Claude immediately." It is:

```text
recover anchors -> root diagnosis -> compact packet -> Claude review -> receipt -> main-agent synthesis
```

Natural-language model routing:

| User Says | Route |
| --- | --- |
| "Claude 用 opus / 4.8" | build packet, request `model_alias: opus`, capture receipt |
| "Claude 省额度 / sonnet" | request `model_alias: sonnet` |
| "持续 reviewer" | bounded resume session with max turns and close condition |
| "不要 Claude" | skip model call and record why |

## Maestro Role Config Later

Inspect:

```powershell
maestro config delegate show --json
```

Interactive role editor:

```powershell
maestro config delegate roles
```

Role mappings are fallback chains. If every role resolves to Codex, Maestro is doing multi-role but not multi-model. Treat role config as a later optimization, not the first user-facing workflow.

Only configure roles after deciding a durable policy, for example:

- `review` and `brainstorm`: Claude then Codex
- `implement`: Codex
- `research`: Codex unless Gemini/Qwen is installed

For now, prefer direct `cc2` one-shot review over changing Maestro role config.

## Async Boundaries

- Codex App thread tools can message Codex threads.
- Maestro delegate can run async and receive `delegate message`.
- Maestro `msg` records coordination; it does not force a model to read.
- `cc2 --resume` gives Claude continuity, but the main agent still sends each turn.
- Claude interactive TUI is human-driven unless a working input/remote-control bridge is configured.
