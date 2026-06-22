# Personal Dev OS: skill + init template 设计稿

## 先回答你的问题

这是可以做成 skill，但不是“只写一个 skill”。

更准确地说，它应该是你的个人开发工作流系统：

- 全局个人 skill：负责触发、判断、澄清、编排、恢复上下文。
- 项目/worktree 初始化模板：负责把规则、状态文件、交接模板放进当前项目。
- Maestro/Ralph：负责在边界清楚后执行固定链路或长流程推进。
- Codex App 会话通信：负责让主会话和 worker 会话传递任务、回执、验收结果。

所以它属于“你的 skill”，但它不应该把所有东西都塞进 `SKILL.md`。`SKILL.md` 只放最核心、最通用、最不容易变的工作流。项目细节、业务资料、阶段计划、UI 验收、样本分析、线程状态，都应该放在项目本地 `.workflow` 和 `docs/dev-os` 里。

## 它像不像 /init？

像，但应该比普通 `/init` 更强。

普通 `/init` 通常只是生成或更新项目说明，例如 `AGENTS.md`。你需要的是一个“个人开发 OS init”：

- 初始化项目规则。
- 初始化任务状态。
- 初始化 open threads。
- 初始化 worker 回执模板。
- 初始化 UI/UX、样本、生成图、人审 gate。
- 初始化 Maestro 使用入口。
- 初始化 Codex App 多会话协作协议。

可以理解成：

```text
/init = 让 Codex 知道这个项目
personal-dev-os init = 让 Codex 按你的开发方式管理这个项目
```

## 新项目和已有项目怎么区分？

新项目最适合直接初始化。

新项目没有历史包袱，可以直接放入统一结构：

```text
AGENTS.md
.workflow/current.yaml
.workflow/open_threads.yaml
.workflow/verification.yaml
.workflow/thread_registry.yaml
.workflow/templates/worker_receipt.yaml
.workflow/templates/ux_issue.yaml
docs/dev-os/README.md
docs/dev-os/command-intent-map.md
docs/dev-os/role-gates.md
```

已有项目不能粗暴覆盖。

已有项目应该走 adopt 模式：

1. 读取现有 `AGENTS.md`、TODO、计划、交接文档、失败记录。
2. 不直接重写旧文档，先建立映射。
3. 新建 `.workflow` 作为轻量状态层。
4. 把旧文档分类为：主线、待确认、历史方案、失败复盘、可复用规则。
5. 只把“长期有效”的规则提升到项目 `AGENTS.md`。
6. 把业务细节留在项目本地，不污染全局 skill。

对 `ozon-erp` 这种已经很乱、规则很重、二开失败多次的项目，应该先 adopt，再重构，不应该直接“全局化”。

## 推荐架构

### 1. 全局个人 skill

建议路径：

```text
C:\Users\asus\.codex\skills\personal-dev-os\SKILL.md
```

它负责这些通用行为：

- 当你说“开发 OS”“长任务闭环”“初始化项目”“按我的流程推进”“需求澄清”“多会话编排”时触发。
- 判断请求是模糊需求、小目标、长任务、UI/UX、样本分析、生成图、二开救援，还是纯实现。
- 模糊需求先复述目标，再问 1-3 个关键问题。
- 小目标边界清楚时直接执行，不强行 Maestro。
- 长任务拆成 3-7 个可恢复子任务。
- 主 agent 负责澄清、编排、收口、验收、上下文恢复。
- worker/subagent 只负责独立分析、实现、验证，不决定产品方向。
- 每个 worker 必须交回 receipt。
- 压缩上下文前后都依赖 `.workflow` 恢复，而不是靠聊天记录记忆。

这个 skill 要保持薄，不放 Ozon、Canvas、1688、爆品、套图这些业务细节。

### 2. 项目初始化模板

建议路径：

```text
D:\Agents\personal-dev-os-template
```

它像一个可复制的项目骨架，适合新项目和新 worktree。

核心文件：

```text
AGENTS.md
.workflow/current.yaml
.workflow/open_threads.yaml
.workflow/verification.yaml
.workflow/thread_registry.yaml
.workflow/templates/worker_receipt.yaml
.workflow/templates/ux_issue.yaml
.workflow/templates/session_recovery_brief.md
docs/dev-os/README.md
docs/dev-os/command-intent-map.md
docs/dev-os/role-gates.md
```

模板负责项目本地状态，不污染全局。

### 3. Maestro/Ralph

Maestro 不应该替代主 agent 的判断。

推荐分工：

```text
主 agent：需求澄清、产品方向、任务排序、验收标准、上下文恢复
Maestro：清晰任务的流程化执行
Ralph：边界清楚的长生命周期任务推进
worker/subagent：独立分析、实现、测试、审查
```

适合 Maestro/Ralph 的任务：

- 已有明确目标和验收标准。
- 可拆成阶段。
- 不需要频繁让你判断产品方向。
- 失败后能用 receipt 恢复。

不适合直接 Ralph 一路跑的任务：

- “我对 UI 不满意，但不知道哪里不满意。”
- “帮我做爆品分析，但样本标准还没定。”
- “帮我做电商套图生成链路，但输出质量标准还没定。”
- “基于旧项目重做，但哪些旧功能保留还没确认。”

这些要先走 PM/FDE/UX gate，然后才能进入 Maestro/Ralph。

### 4. Codex App 多会话通信

这是你想要的“半自动闭环”的关键。

推荐协议：

```text
main thread
  - 需求澄清
  - 拆任务
  - 派 worker
  - 读取 worker receipt
  - 更新 .workflow
  - 做最终判断

worker thread
  - 只处理一个独立任务
  - 不改变产品方向
  - 不吞掉不确定点
  - 完成后返回 receipt
```

worker receipt 至少包含：

```yaml
task_id:
scope:
files_read:
files_changed:
commands_run:
evidence:
risks:
open_questions:
next_recommended_step:
status: done | blocked | needs_review
```

这样即使上下文压缩，主会话也可以靠 `.workflow` 和 receipt 恢复，而不是靠记忆。

## 角色定义

### 主 agent

主 agent 是总编排者，不应该只做代码执行。

职责：

- 复述目标。
- 发现不确定点。
- 决定是否需要澄清。
- 定义验收标准。
- 拆任务。
- 派发 worker。
- 读取回执。
- 更新状态。
- 判断是否进入实现、测试、UI 验收、复盘。

### PM 视角

关注：

- 用户价值是什么。
- 当前阶段是不是值得做。
- 什么算完成。
- 哪些不做。
- 哪些必须让你确认。

### FDE 视角

关注：

- 数据合同。
- 接口边界。
- 错误状态。
- 验证方式。
- 回滚和恢复点。

### UX/UI 视角

关注：

- 你是否能直接看见效果。
- UI 是否符合你的真实工作流。
- 是否有渐进式披露。
- 是否能用浏览器或截图验证。
- 不能只用后端测试代表完成。

### Research/Domain 视角

适合 Ozon、1688、爆品、货源、样本分析。

关注：

- 样本怎么选。
- 样本是否代表目标场景。
- 结论是否能转成提示词、字段、流程、组件。
- 有没有证据来源。

### QA/Verifier 视角

关注：

- smoke 测试。
- UI 可见验证。
- 数据链路验证。
- 失败复现。
- 截图、日志、命令输出证据。

## 你的常见模糊输入应该怎么被处理

### “我对 UI 不满意”

不应该直接改 UI。

应该先进入 UX 澄清：

```text
我理解你不是要随机美化，而是现在界面不贴合你的电商套图工作流。
我需要先确认：
1. 你最不满意的是布局、效率、视觉质感，还是生成链路不可见？
2. 你希望先改哪个页面或流程？
3. 你能接受用截图做验收吗？
```

然后产出 `ux_issue.yaml`，再进入实现。

### “帮我二开 canvas”

不应该直接写功能。

应该先问：

- 是保留原 canvas 能力，还是新建套图工作台？
- 最核心链路是采集、样本分析、提示词生成、多图参考、批量生成，还是导出？
- 第一版 MVP 你要能看到什么？

### “我想用 Maestro 跑”

不应该默认 Ralph 一路执行。

应该先判断：

```text
清楚小目标：直接执行或 Maestro。
清楚长任务：Ralph。
模糊产品任务：先澄清和建 plan，再 Ralph。
UI/样本/生成图任务：必须先有人审 gate。
```

## 推荐使用方式

### 新项目

你可以这样说：

```text
$personal-dev-os
帮我在这个项目初始化我的开发 OS，适合新项目。
```

主 agent 应该做：

1. 读取当前项目。
2. 生成项目本地 `AGENTS.md` 和 `.workflow`。
3. 判断是否安装 Maestro。
4. 建立第一版 `current.yaml`。
5. 给你一张“怎么继续说话”的命令表。

### 已有项目

你可以这样说：

```text
$personal-dev-os
adopt 这个已有项目，不要覆盖旧文档。先梳理主线、历史计划、失败记录和当前下一步。
```

主 agent 应该做：

1. 只读梳理旧文档。
2. 标记哪些是主要交接文件。
3. 生成 `.workflow` sidecar。
4. 列出可删除、可归档、要保留、要提升成规则的内容。
5. 等你确认后再改项目规则。

### 长任务

你可以这样说：

```text
$personal-dev-os
这是长任务。先不要实现，先按 PM/FDE/UX/Research 多视角拆解，并给出 3-7 个可恢复子任务。
```

### 清楚的小目标

你可以这样说：

```text
这是小目标，不需要 Maestro。直接实现，但说明完成标准和验证方式。
```

### 不需要澄清的 Ralph

你可以这样说：

```text
$maestro-ralph
边界已清楚：目标是 X，验收是 Y，不能做 Z。按当前项目 .workflow 执行，并在每阶段写 receipt。
```

## 什么应该进全局，什么应该留项目

### 适合进全局 skill

- 模糊需求先澄清。
- 主 agent 负责编排。
- 子代理只做独立任务。
- UI/样本/生成图必须有人审 gate。
- 长任务拆 3-7 个可恢复子任务。
- worker 必须交 receipt。
- 压缩上下文依赖 `.workflow` 恢复。
- 本地有权限就不要自我降级成只读。

### 不适合进全局 skill

- Ozon 具体业务规则。
- Canvas 具体二开方案。
- 某次 6/17 文档的结论。
- 某个 worktree 的失败记录。
- 某个 UI 页面设计细节。
- 某个采集插件的数据字段。

这些应该留在项目本地。

## 是否全面？

如果只写一个长 `SKILL.md`，不全面，而且会变重。

如果按下面四层落地，就比较全面：

```text
全局 skill
  负责触发和工作流判断

项目 init 模板
  负责项目状态、交接、验收、线程登记

Maestro/Ralph
  负责清晰任务的流程执行

Codex App thread protocol
  负责多会话派发、回执、验收、恢复
```

这套东西的目标不是让 AI 永远全自动，而是让它在“不需要你判断”的地方自动推进，在“容易走偏”的地方主动停下来问你。

## 建议落地顺序

### T1: 先定设计

先确认这份设计是不是符合你的真实痛点。

### T2: 创建全局薄 skill

创建：

```text
C:\Users\asus\.codex\skills\personal-dev-os\SKILL.md
```

只放通用触发和流程判断。

### T3: 创建项目 init 模板

创建：

```text
D:\Agents\personal-dev-os-template
```

放可复制到任意项目/worktree 的模板。

### T4: 给已有项目做 adopt

用 `ozon-erp` 或某个 worktree 试一次：

```text
adopt，不覆盖旧文档，先梳理主线和交接文件。
```

### T5: 接入 Maestro

只在项目内安装或初始化 Maestro，不把业务规则装到全局。

### T6: 接入 Codex App 多会话协议

用 `thread_registry.yaml` 和 `worker_receipt.yaml` 试一次主会话派 worker 的闭环。

### T7: 再考虑 hooks

hooks 可以做，但不要第一步就做全自动。

适合 hook 化的动作：

- worker 完成后写 receipt。
- session 结束前更新 recovery brief。
- 长任务开始时检查 open threads。
- 测试后写 verification。

不适合一开始 hook 化的动作：

- 自动决定产品方向。
- 自动确认 UI 满意。
- 自动确认生成图质量。
- 自动发布、下单、写外部平台。

## 结论

这不是“给 Maestro 加一堆规则”，也不是“把你的所有经验塞进全局 AGENTS.md”。

更好的形态是：

```text
一个很薄的个人 skill
+ 一个可复制的项目 init 模板
+ 项目本地 Maestro/Ralph
+ Codex App 多会话 receipt 协议
+ 明确的人审 gate
```

它更适合新项目和新 worktree，但也可以通过 adopt 模式接管已有项目。

对你来说，最重要的不是“自动跑得更猛”，而是让每次开发都能回答四个问题：

1. 现在主线是什么？
2. 哪些问题还没确认？
3. 哪些任务可以让 worker 自己做？
4. 做完后有什么证据证明没跑偏？
