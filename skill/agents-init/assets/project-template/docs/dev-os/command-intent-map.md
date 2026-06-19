# Command Intent Map

The user does not need to memorize exact commands. Route natural language to the same actions.

| User says | Main agent should do |
| --- | --- |
| `$agents-init menu` | Show recover/clarify/brainstorm/plan/dispatch/route/save options. |
| `$agents-init orchestrate` / "我说不清但方向不对" / "怎么推进" | Recover state, infer semantic signals, and decide direct/Maestro/Codex App/human gate routing. |
| "初始化这个项目" | Create missing Agents Init files, then update `.workflow/current.yaml`. |
| "adopt 这个已有项目" | Do not overwrite. Classify old docs/TODO/rules and create sidecar `.workflow`. |
| "恢复当前项目" / "现在到哪了" | Read `.workflow/current.yaml`, `task.yaml`, `open_threads.yaml`, `verification.yaml`, `thread_registry.yaml`. |
| "检查 agents-init 配置" / "doctor" | Run workflow validation plus Maestro/Codex environment diagnosis. |
| "给我测试这个 skill 是否会跑偏" | Print pressure-test prompts and expected routes. |
| "我不知道用哪个命令" / "帮我判断怎么走" | Run route-intent and preserve matched signals in open threads. |
| "注册主会话" | Record the active main Codex thread id in `.workflow/thread_registry.yaml` when available. |
| "我很模糊" / "我不会表达" | Restate goal, list uncertainty, ask at most 1-3 questions. |
| "我对 UI 不满意" | Create/update a UX issue first; do not jump straight to code. |
| "分析爆品/货源/样本" | Create/update a sample decision or research task with evidence boundaries. |
| "多角度分析" | Use PM/FDE/UX/Data/Test views; synthesize into one task card or plan. |
| "开 worker" / "开 Codex 子会话" | Register worker in `thread_registry.yaml`, give one bounded task and receipt contract. |
| "读取 worker 回执" | Read worker output, accept/reject receipt, update workflow and verification. |
| "用 Maestro/Ralph" | Use only after the current gate and human pause points are clear. |
| "小目标很清楚" | Execute directly with completion standard and verification. |
| "压缩前保存状态" / "新会话交接" | Update current/task/open_threads/verification and write a recovery brief. |

## Route Intent Caveat

Natural-language routing is advisory. If one prompt contains multiple signals, do not discard the weaker signals. Put them into `open_threads.yaml` or the task card so they can be handled after the first gate.

If the phrase is not in this table, do not assume direct mode. Use the main-agent orchestration loop.
