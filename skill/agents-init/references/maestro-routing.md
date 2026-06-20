# Maestro Routing

Use this reference when deciding whether to use direct work, native subagents, Codex App worker threads, Maestro delegate, Maestro/Ralph, or Maestro knowledge/search/wiki/KG/workspace/team/overlay tools.

## Positioning

Maestro is a workflow/lifecycle/knowledge/delegate/team/worktree engine. `agents-init` is the main-agent console that decides when to use Maestro and when to pause.

Maestro does not replace:

- user requirement clarification;
- UI/generated-image/sample acceptance;
- main-agent final judgment;
- Codex App thread registry and receipt ingest.

## Route Table

| Route | Use When | Required Output |
| --- | --- | --- |
| Direct | Small clear task | Completion standard and verification |
| Grill | Fuzzy requirement | Clarified task card |
| Brainstorm | Need PM/FDE/UX/Data/Test views | Synthesis and open threads |
| Blueprint | Chaotic feature/second-development | Requirement/module/risk/acceptance map |
| Worker | Independent bounded task | Worker receipt |
| Maestro delegate | Role-routed analysis/write task | Delegate id plus raw output/transcript checked by main agent |
| Ralph | Clear lifecycle with gates | Stage receipt and human pause points |
| Maestro spec/knowhow | Stable constraints or reusable recipes/decisions | Spec/knowhow entry or reference |
| Maestro wiki/search/KG | Need to recover prior knowledge, code graph, or cross-workspace context | Retrieved anchors with proves/does_not_prove |
| Maestro workspace/domain | Reusable knowledge across projects or domain vocabulary | Linked workspace/domain entry and scope |
| Maestro team/msg | Multiple actors may conflict or need activity signaling | Conflict/activity evidence mapped to thread registry |
| Maestro overlay | Need non-invasive guardrails or workflow patches | Overlay purpose, target, rollback path |
| Maestro composer/player | Repeatable workflow should become a template | User-accepted workflow template and checkpoints |

## Knowledge And Context Routing

Use Maestro knowledge surfaces before external search when the question is about local or previously learned project context:

| User Intent | Maestro Surface | Main-Agent Gate |
| --- | --- | --- |
| "Didn't we already discuss this?" | `search`, `wiki`, `knowhow` | Cite anchors before clarification |
| "What code area is affected?" | `kg`, codebase docs/search | Evidence before implementation |
| "This rule should be remembered" | `spec` for constraints, `knowhow` for recipes/decisions | Main decides active vs reusable |
| "This workflow repeats" | `knowhow` tool, composer/player | User accepts before codifying |
| "Use this across projects" | `workspace`, `domain` | Define applies_when/does_not_apply_when |
| "Multiple agents may edit" | `team/msg`, registry preflight | Main conflict gate |

Do not dump all knowledge into `AGENTS.md`. Keep:

- current task state in `.workflow`;
- active/superseded corrections in memory points;
- stable constraints in Maestro specs;
- recipes, compacts, decisions, and references in Maestro knowhow/wiki;
- code impact and large-codebase retrieval in KG/search.

The main agent should use these surfaces proactively. The user should be able to say "这个要记住", "联系之前上下文", "查旧项目怎么融入", or "不要一直堆文档", and the main agent should choose the maintenance action:

| Natural Language Meaning | Main-Agent Maintenance Action |
| --- | --- |
| "以后都要遵守" | add/update Maestro `spec`, with `.workflow` evidence |
| "这个流程以后复用" | add Maestro `knowhow` recipe or decision |
| "我反复纠正这个" | add/supersede `.workflow/memory_points.yaml` |
| "这次方向变了" | mark old memory/open thread superseded before writing new one |
| "旧项目要融入哪里" | run KG/search/code retrieval before plan |
| "文档太多了" | summarize active conclusions, archive raw material, close stale threads |
| "之前不是说过吗" | search `.workflow`, spec, knowhow, KG/search before clarification |

If Maestro KG is missing, record that as a verification boundary and fall back to bounded `rg`/code search. Do not claim KG-backed context until `kg stats/search/context` succeeds.

## Delegate Commands

Useful forms:

```powershell
maestro delegate "analyze auth module" --role analyze --mode analysis --cd "<project>" --async
maestro delegate status <execId>
maestro delegate output <execId>
maestro delegate message <execId> "extra context"
maestro delegate message <execId> "follow-up" --delivery after_complete
maestro delegate cancel <execId>
```

Prompt shape for delegates:

```text
PURPOSE: goal + why + success criteria
TASK: step 1 | step 2 | step 3
MODE: analysis|write
CONTEXT: files/dirs/state
EXPECTED: receipt format and quality bar
CONSTRAINTS: scope limits and human gates
```

## Role Routing

Prefer `--role` over hardcoding a tool:

```text
analyze, explore, review, implement, plan, brainstorm, research
```

`--to` overrides `--role`.

Record the actual tool used. If local config routes every role to Codex, do not claim true multi-model review. State it as multi-role analysis unless Claude/Gemini/Qwen/etc. actually ran.

For non-Codex delegates, record both metadata and raw output. A run is usable only if `maestro delegate output <execId>` or the raw jsonl/transcript contains non-empty task-relevant output. Stale streams, empty output, auth errors, or model unavailable errors make the delegate `inconclusive` or `failed` even when a meta/status summary looks successful.

## Delegate Role Configuration

Maestro supports role-to-tool routing through `cli-tools.json`.

Supported roles:

```text
analyze, explore, review, implement, plan, brainstorm, research
```

Config lookup order:

1. workspace config: `<project>/.maestro/cli-tools.json`
2. global config: `~/.maestro/cli-tools.json`
3. Maestro defaults

Each role can map directly to a tool or use a fallback chain. The TUI command is:

```powershell
maestro config delegate roles
```

Non-interactive inspection:

```powershell
maestro config delegate show --json
```

Example config shape:

```json
{
  "tools": {
    "claude": { "enabled": true, "primaryModel": "opus", "tags": ["fullstack"], "type": "builtin" },
    "codex": { "enabled": true, "primaryModel": "gpt-5.5", "tags": ["fullstack", "backend"], "type": "builtin" }
  },
  "roles": {
    "review": { "fallbackChain": ["claude", "codex"] },
    "brainstorm": { "fallbackChain": ["claude", "codex"] },
    "implement": { "fallbackChain": ["codex"] }
  }
}
```

For users with multiple Claude profiles or wrapper commands, prefer a declarative profile policy over hardcoding a local account. A usable Maestro Claude config may need per-tool environment such as `CLAUDE_CONFIG_DIR`, but that must be treated as local configuration:

```json
{
  "tools": {
    "claude": {
      "enabled": true,
      "primaryModel": "opus",
      "tags": ["fullstack"],
      "type": "builtin",
      "env": { "CLAUDE_CONFIG_DIR": "<local-claude-profile-dir>" }
    }
  }
}
```

Only use fields supported by the installed Maestro build. If the local build ignores `env`, requires an adapter patch, or loses support after an npm update, record the route as `needs_repair` and fall back to direct `cc2` or a human-driven packet.

Do not change role config just to satisfy a single prompt unless the user accepts the routing policy. For this user, prefer:

- Codex for implementation, local execution, broad code reading, and routine verification.
- Claude for scarce high-value review, architecture critique, PM/FDE/UX tradeoff analysis, and plan challenge.
- Gemini/Qwen/opencode/agy only when installed and configured.

If Maestro's Claude adapter is inconclusive, use direct `cc2` capturable CLI as a separate route and record that it was not a Maestro delegate.

For Claude, use `cc2` primarily as a local profile/alias reference and fallback route. If `cc2` works because it selects a specific account/profile, inspect that wrapper behavior and configure or smoke Maestro's Claude tool against the same profile when possible. Do not replace the Maestro delegate lifecycle with a direct `cc2` context dump unless Maestro is inconclusive or the user explicitly wants a known `cc2` session.

Command parameters and config have different meanings:

- `cc2 --model opus` or `maestro delegate --to claude` is a one-call request.
- `<project>/.maestro/cli-tools.json` or `~/.maestro/cli-tools.json` is a durable role-routing policy.
- `--to claude` overrides the role for that command; it does not prove `review` or `brainstorm` roles now route to Claude.
- `maestro config delegate show --json` is the inspection command for current durable routing.

## Doctor And Repair Boundary

`agents-init` should diagnose and guide Maestro configuration because bad model/profile routing creates false multi-model evidence. It should not silently own external accounts or mutate global tool installs.

Doctor should check:

- which `maestro` binary is active and whether it is npm/global/project-scoped;
- whether workspace config overrides global config;
- whether role mappings actually route review/brainstorm/plan to Claude or Codex;
- whether the configured Claude model alias is accepted by the underlying CLI;
- whether the intended Claude profile is active, for example through `CLAUDE_CONFIG_DIR`;
- whether a project-approved wrapper such as `cc2` exists and smokes successfully;
- whether raw delegate output contains a task-relevant token, not just a completed meta status;
- whether local package patches are required and may be overwritten by updates.
- whether `maestro --version` changed since the last successful delegate smoke.

Repair policy:

- reading configs and reporting diffs is allowed;
- writing project-local `.maestro/cli-tools.json` requires user confirmation;
- writing global `~/.maestro/cli-tools.json` requires stronger confirmation and a rollback note;
- writing `.workflow/model_policy.yaml` is project policy and should record command/profile labels without secrets;
- patching npm-installed Maestro code is a temporary local repair only, never a portable skill default;
- credential refresh, account switching, quota purchase, and destructive config reset must remain manual user actions.

If the user is a multi-Claude user, define named profiles such as `default`, `account2`, or `work-reviewer` and route by profile label. Do not store secrets or assume a profile can be used just because it exists; smoke it and record the result.

After a Maestro npm/global update or binary source change, downgrade previously patched Claude routes to `needs_post_update_smoke`. Run a tiny delegate smoke and record `maestro_binary_version`, config source, profile label, and raw output before trusting the route again.

## Interactive And Multi-Model Reality Check

Maestro can expose multi-model routing through `delegate`, role configuration, and CLI/tool adapters. It also exposes interactive/lifecycle surfaces such as `view`, `coordinate`, `ralph`, `launcher`, `team/msg`, and knowledge commands. That does not automatically mean the current main Codex session can type into an already-open terminal TUI.

Before claiming a multi-model route is usable, test the exact path:

| Path | Success Means | Failure Means |
| --- | --- | --- |
| `maestro delegate --to claude ...` | non-empty usable output or receipt | record model/auth/adapter failure |
| `cc2 --safe-mode -p "..." --model claude-sonnet-4-6 --output-format json` | non-interactive Claude output is captured | use interactive packet or repair auth/config |
| `cc2 --safe-mode -p "..." --resume <session_id>` | capturable continuous Claude context is preserved | do not use for durable role memory until session registry exists |
| `cc2` interactive TUI | the user can paste a packet and return a receipt | main agent cannot claim direct TUI control unless a terminal input tool exists |
| Codex App thread/subagent | Codex-model receipt is available | multi-role, not multi-model |

If a terminal snapshot shows a Claude TUI open but there is no tool for sending keystrokes to it, the main agent may read the terminal state but must not claim it can directly converse through that TUI. Generate a shared context packet and ask the user to paste it, or use the capturable `cc2 --safe-mode -p ... --resume` path when a structured review is enough.

Check Maestro delegate raw evidence, not only summary status. A meta file may show the requested model while the jsonl output still contains an underlying model error. The raw output decides whether the delegate is accepted.

## Async Follow-Up Commands

Maestro delegate supports background tasks and follow-up messages:

```powershell
maestro delegate --role review --mode analysis --async --cd "<project>" "<bounded prompt>"
maestro delegate status <execId>
maestro delegate tail <execId>
maestro delegate output <execId>
maestro delegate message <execId> "follow-up context"
maestro delegate message <execId> "queue after done" --delivery after_complete
```

`agent-msg` is a team message ledger:

```powershell
maestro msg send -s <session> --from main --to reviewer --type request --summary "short" "message"
maestro msg list -s <session>
maestro msg status -s <session>
```

Use `agent-msg` for coordination evidence, not as proof that another model consumed the message.

## Windows And Codex Limits

- Maestro Codex hooks are documented as not supported on Windows in the current local guide.
- Codex hooks are advisory and limited compared with Claude hooks.
- Terminal backend depends on a supported terminal environment such as tmux or WezTerm; normal Windows PowerShell should not be assumed to support it.
- Treat Maestro delegate as bounded and receipted. Do not rely on it as the only control plane.

## Human Gate Rule

Never auto-advance Maestro/Ralph across these:

- UI/UX acceptance;
- sample/reference selection;
- generated image quality;
- seller-ready/export/publish claims;
- external account/platform writes.
