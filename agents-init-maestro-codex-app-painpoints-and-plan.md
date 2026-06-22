# Agents Init + Maestro + Codex App 痛点与集成计划

## 0. 当前结论

`agents-init` 不应该替代 Maestro，也不应该和 Maestro 抢职责。

它的定位应是：

```text
给当前项目安装一个主 agent 操作台：
识别用户自然语言 -> 需求澄清/角色分析/任务拆分 -> 路由到 Maestro/Ralph/Codex worker/direct -> 收 receipt -> 更新 .workflow -> 让新会话可恢复。
```

换句话说：

```text
Maestro = 工作流引擎、知识管理、Ralph 长链、团队/多 CLI/worktree 能力
Codex App = 真实会话、线程通信、浏览器、本地文件、工具执行环境
agents-init = 让主 agent 在项目里会用 Maestro + Codex App 的适配层和操作台
```

所以它不会冲突。正确关系是：

```text
agents-init 先初始化/补全项目控制面
-> 检测 Maestro 是否存在
-> 没有就建议/执行 maestro install
-> 有就读取 Maestro 产物
-> 补上 Codex App 主会话/worker/receipt/人审 gate
-> 用户用自然语言，主 agent 选择 Maestro 指令或 Codex worker
```

## 1. 你反复提出的痛点

### 1.1 不会用命令

你不想记 npm、git、Maestro、Ralph、worktree、线程 id、测试命令。

需要的是：

```text
你说自然语言
主 agent 识别意图
主 agent 替你执行命令或派 worker
```

### 1.2 需求经常模糊

你经常说：

```text
我不满意 UI
我想二开 canvas
我脑子很乱
我不知道怎么开发
```

这不是“用户问题”，而是开发系统必须支持的输入形态。

正确处理：

```text
模糊输入 -> grill / brainstorm / task card
不要直接实现
最多问 1-3 个确认问题
```

### 1.3 长任务容易跑偏

尤其是 Ozon/Canvas/电商套图：

```text
样本分析
爆品参考
1688 货源事实
套图 slot
生图工作流
Canvas 可视化
导出 manifest
UI 验收
```

这些不是一个小 TODO 能解决的。必须有 gate、receipt、open_threads。

### 1.4 上下文压缩后丢主线

你的典型失败模式：

```text
澄清越多 -> 文档越多 -> 上下文越长 -> 压缩 -> 主线丢失 -> 做了窄任务但不是你要的
```

解决方式：

```text
.workflow/current.yaml
.workflow/agents-init.yaml
.workflow/task.yaml
.workflow/open_threads.yaml
.workflow/verification.yaml
.workflow/thread_registry.yaml
```

聊天记录不能当唯一记忆。

### 1.5 UI/生成图/样本不能靠后端测试

你看不到后端测试，所以后端测试通过对你没意义。

这些必须有人审 gate：

```text
UI 是否满意
生成图质量
样本是否代表需求
Ozon 参考是否只是风格参考
1688 事实是否可靠
Canvas 工作流是否看得懂
导出包是否符合预期
```

### 1.6 旧项目规则很重，但也有价值

旧 Ozon 有很多规则、TODO、交接、index、active、handoff。问题不是全删，而是：

```text
旧规则太重 -> 不适合每次默认加载
但里面有很多真实失败经验 -> 需要 salvage/adopt
```

### 1.7 想要多 agent，但不是无脑多 agent

你想要：

```text
主 agent = 编排、澄清、验收、收口
worker = 独立分析/实现/验证
worker 完成后给主 agent receipt
主 agent 决定下一步
```

worker 不应该变成第二个产品负责人。

### 1.8 主 agent 也可能换会话

你现在的主会话 id 是：

```text
019ebb36-fbe7-73e2-b026-e804056cae72
```

但以后新开会话后，新的主 agent 需要接管。

所以必须有：

```text
register-main
thread_registry
handoff / recovery brief
旧主会话 historical
新主会话 active
```

## 2. Maestro 作者资料入口

当前已读取/确认的入口：

- [Maestro-FLow 主帖](https://linux.do/t/topic/2102464)
- [作者 topics 页](https://linux.do/u/catlog22/activity/topics)

作者 topics 页可见的 Maestro/CCW 相关知识入口包括：

| 主题 | URL | 用途 |
| --- | --- | --- |
| Maestro-Flow-One skill | https://linux.do/t/topic/2122097 | 判断 Maestro 是否已有“一包成 skill”的方案 |
| Maestro-FLow 主帖 | https://linux.do/t/topic/2102464 | 总体能力：闭环、知识复用、团队协作、worktree、多 CLI |
| Codex /goal 长时多 agent | https://linux.do/t/topic/2109656 | 研究 Codex 长时多 agent 和 goal 闭环 |
| CCW 长期贴 | https://linux.do/t/topic/1863021 | 作者早期工程化工作流思想来源 |
| Maestro 知识管理系统 | https://linux.do/t/topic/2149143 | spec/wiki/knowhow/learn/复盘沉淀 |
| Maestro 0.4.9 agent team 多 CLI | https://linux.do/t/topic/2212861 | agent team、多 CLI、长链能力增强 |
| CCW V7 / codex csv spawn / Maestro 展望 | https://linux.do/t/topic/1806070 | worktree/team/spawn 相关背景 |
| CCW 6.3 Issue-loop | https://linux.do/t/topic/1463050 | issue-loop 工作流参考 |
| CCW V6.2 memory / resume / context search | https://linux.do/t/topic/1349155 | memory、resume、上下文搜索参考 |
| 工作流与提示词分享 | https://linux.do/t/topic/1242888 | 大型代码库功能新增/debug 工作流 |

这些还没有全部深读。下一阶段应该把它们沉淀成：

```text
D:\Agents\maestro-knowledge-base\
  index.md
  maestro-flow-main.md
  maestro-flow-one.md
  codex-goal-multi-agent.md
  knowledge-management.md
  agent-team-multi-cli.md
  ccw-memory-resume.md
```

## 3. agents-init 的正确定位

### 3.1 不是

`agents-init` 不是：

- Maestro 的替代品。
- 单纯 `/init`。
- 一个长期业务规则垃圾桶。
- 一个让 AI 完全无人值守的开关。
- Ozon 专用 skill。

### 3.2 是

`agents-init` 是：

```text
Codex App 项目主 agent 控制面初始化器
```

它负责：

- 新项目初始化。
- 旧项目 adopt 补全。
- 检测 Maestro 是否安装/初始化。
- 补上 Codex App 主会话/worker/receipt 协议。
- 给主 agent 一套菜单和路由表。
- 把自然语言映射到 Maestro/Ralph/direct/worker。
- 把需求澄清、open_threads、verification、thread_registry 固化。

## 4. agents-init 与 Maestro 如何一起用

### 4.1 初始化顺序

理想流程：

```text
用户：$agents-init init/adopt 当前项目

主 agent：
1. 检查项目是否已有 AGENTS.md / .workflow / Maestro 产物。
2. 新项目：复制 agents-init 模板。
3. 旧项目：不覆盖，补缺失 sidecar。
4. 检查 maestro CLI 是否存在。
5. 没有 Maestro：安装或提示执行 npm install / maestro install。
6. 有 Maestro：读取 .agents / .codex/skills / .workflow / docs。
7. 补 .workflow/agents-init.yaml。
8. 注册主会话 id。
9. 输出 menu。
```

### 4.2 运行时路由

```text
用户说：我很模糊 / UI 不满意
-> agents-init grill
-> 需求澄清，不写代码

用户说：多角度分析
-> agents-init brainstorm
-> PM/FDE/UX/Data/Test

用户说：分析很多条件
-> route to maestro-analyze 或 worker

用户说：长任务推进
-> route to Ralph
-> 但 UI/样本/生成图 gate 必须停

用户说：小目标清楚
-> direct，不强行 Maestro

用户说：开子会话
-> Codex App worker
-> receipt
-> 主 agent ingest
```

### 4.3 不冲突的职责边界

| 层 | 职责 |
| --- | --- |
| 全局规则 | 你的稳定偏好：模糊先澄清、主 agent 编排、人审 gate |
| agents-init skill | 项目初始化/adopt/菜单/路由/主会话登记 |
| Maestro | 工作流命令、Ralph、知识管理、团队/多 CLI、worktree |
| Codex App | 真实线程、跨会话消息、浏览器、本地文件、工具调用 |
| 项目 `.workflow` | 当前主线、任务、open_threads、verification、thread_registry |

## 5. 主会话和新会话接管

### 5.1 当前主会话

当前主会话 id 已登记为：

```text
019ebb36-fbe7-73e2-b026-e804056cae72
```

位置：

```text
E:\ozon-erp\.worktrees\maestro-canvas-v030-lab\.workflow\agents-init.yaml
E:\ozon-erp\.worktrees\maestro-canvas-v030-lab\.workflow\thread_registry.yaml
```

### 5.2 新主会话接管方式

推荐自然语言：

```text
$agents-init register-main
这是新的主会话，接管当前项目。请读取 .workflow/agents-init.yaml 和 thread_registry，把旧主会话标为 historical，把当前会话注册为 active。
```

如果主 agent 能读到当前 thread id，则自动写入。

如果不能读到，则用户给：

```text
我的新主会话 id 是 <thread-id>，注册为 active main agent。
```

### 5.3 主 agent 新建并交接给新会话

可行，但要明确：

- 当前工具可以 create_thread。
- 可以 read_thread。
- 可以 send_message_to_thread。
- 可以 archive thread。
- 没有物理 delete 工具。

可行流程：

```text
当前主 agent 创建新 thread
-> prompt 包含项目路径、read order、当前 gate、forbidden claims
-> 新 thread 输出接管 receipt
-> 当前主 agent 读取 receipt
-> 当前主 agent 更新 thread_registry
-> 当前主 agent 把新 thread 标 active
-> 当前主 agent 自己变 historical 或暂停
```

这个更像“handoff_thread”，不是完全自动无感迁移。

## 6. 跨会话实测结论

已实测：

```text
worker thread id: 019edc59-f286-7fa0-8d5f-16461f77bd6f
source main thread id: 019ebb36-fbe7-73e2-b026-e804056cae72
result: worker 返回 YAML receipt，主线程读取成功，随后归档 worker
```

证明：

- Codex App 可以创建一次性 worker。
- worker prompt 会带 source_thread_id。
- 主 thread 可以读取 worker 输出。
- worker 可以被 archive。

没有证明：

- 物理删除 thread。
- 长期自动运行。
- Maestro hook 可靠。
- worker 能替代主 agent 做产品判断。

## 7. 是否应该在本项目试跑 agents-init 系统化分析任务

可以，而且建议试。

因为你的当前任务正适合：

```text
研究 Maestro 作者多篇帖子
沉淀知识库
分析 agents-init 与 Maestro/Codex App 的集成
把痛点映射成工作流
更新 skill 和模板
在 Ozon worktree 试用
```

这正是一个典型长任务：

- 多资料源。
- 多阶段。
- 需要需求澄清。
- 需要知识沉淀。
- 需要主 agent 编排。
- 可以派 worker。
- 不应该直接写业务代码。

## 8. 推荐执行计划

### T1: 建立 Maestro 知识库目录

创建：

```text
D:\Agents\maestro-knowledge-base\
```

包含：

```text
index.md
sources.yaml
notes\
```

先记录作者 topics 页所有相关链接，不深读全部。

### T2: 深读核心 4 篇

优先：

1. Maestro-Flow 主帖。
2. Maestro-Flow-One skill。
3. Codex /goal 长时多 agent。
4. Maestro 知识管理系统。

每篇输出：

```text
what_it_solves
commands
artifacts
how_it_maps_to_agents_init
risks
not_yet_understood
```

### T3: agents-init 与 Maestro 能力矩阵

输出：

```text
自然语言意图 -> agents-init menu -> Maestro/Ralph/direct/worker -> 产物 -> 人审 gate
```

### T4: 完善 agents-init

补：

- Maestro 检测。
- Maestro install/adopt 指南。
- 命令路由表。
- 线程交接协议。
- 新主会话接管协议。
- knowledge base 查询入口。

### T5: Ozon worktree 试跑

在：

```text
E:\ozon-erp\.worktrees\maestro-canvas-v030-lab
```

试跑：

```text
$agents-init menu
$agents-init recover
$agents-init grill
$agents-init dispatch-worker
$agents-init ingest-receipt
$agents-init route-maestro
```

但只做分析，不动业务代码。

### T6: 新主会话 handoff 演练

创建一个新主 thread：

```text
role: main_agent_orchestrator_candidate
task: 接管 agents-init + Maestro 知识库分析
```

让它读取 `.workflow/agents-init.yaml`，输出接管 receipt。

当前主 agent 读取后决定是否注册为 active。

### T7: 决定是否把 agents-init 升级为 Maestro 增强外挂

如果 T1-T6 成功，再把定位固化为：

```text
agents-init = Maestro for Codex App adapter / main-agent console
```

## 9. 现在的回答

你的直觉是对的：

```text
agents-init 应该 init 一次后，让主 agent 能在当前项目部署好控制面。
```

但还要补两点：

1. 它要理解 Maestro 的知识体系，不能只自己造一套。
2. 它要支持 Codex App 真实线程：register-main、dispatch-worker、ingest-receipt、handoff-main。

这就是下一阶段工作。
