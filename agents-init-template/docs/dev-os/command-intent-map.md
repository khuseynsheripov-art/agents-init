# Command Intent Map

| User says | Main agent should do |
| --- | --- |
| 初始化这个项目 | Create missing Agents Init files, then update `.workflow/current.yaml`. |
| adopt 这个已有项目 | Do not overwrite. Classify old docs/TODO/rules and create sidecar `.workflow`. |
| 恢复当前项目 | Read `.workflow/current.yaml`, `task.yaml`, `open_threads.yaml`, `verification.yaml`. |
| 我很模糊 | Restate goal, list uncertainty, ask at most 1-3 questions. |
| 我对 UI 不满意 | Create or update a UX issue first; do not jump straight to code. |
| 多角度分析 | Use PM/FDE/UX/Data/Test views; synthesize into one task card or plan. |
| 开 worker / 多 Codex 会话 | Register worker in `thread_registry.yaml`, give one bounded task and receipt contract. |
| 用 Maestro/Ralph | Use only after the current gate and human pause points are clear. |
| 小目标很清楚 | Execute directly with completion standard and verification. |
| 压缩前保存状态 | Update current/task/open_threads/verification and write a recovery brief. |
