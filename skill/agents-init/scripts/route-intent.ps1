[CmdletBinding()]
param(
  [Parameter(Mandatory = $true)]
  [string]$ProjectPath,

  [Parameter(Mandatory = $true)]
  [string]$Prompt,

  [switch]$Json
)

$ErrorActionPreference = 'Stop'

function Test-AnyPattern {
  param(
    [Parameter(Mandatory = $true)][string]$Text,
    [Parameter(Mandatory = $true)][string[]]$Patterns
  )

  foreach ($pattern in $Patterns) {
    if ($Text -match $pattern) {
      return $true
    }
  }
  return $false
}

function New-Route {
  param(
    [Parameter(Mandatory = $true)][string]$Name,
    [Parameter(Mandatory = $true)][string]$Action,
    [Parameter(Mandatory = $true)][string]$Gate,
    [Parameter(Mandatory = $true)][string]$Confidence,
    [Parameter(Mandatory = $true)][string]$Reason,
    [string[]]$ReadFirst = @(),
    [string[]]$Templates = @(),
    [string[]]$Commands = @(),
    [string[]]$MustNot = @(),
    [bool]$HumanGate = $false
  )

  return [ordered]@{
    route = $Name
    recommended_action = $Action
    gate = $Gate
    confidence = $Confidence
    reason = $Reason
    human_gate = $HumanGate
    read_first = $ReadFirst
    templates_to_use = $Templates
    useful_commands = $Commands
    must_not = $MustNot
  }
}

if (-not (Test-Path -LiteralPath $ProjectPath -PathType Container)) {
  throw "ProjectPath does not exist or is not a directory: $ProjectPath"
}

$project = (Resolve-Path -LiteralPath $ProjectPath).Path
$workflow = Join-Path $project '.workflow'
$hasWorkflow = Test-Path -LiteralPath (Join-Path $workflow 'current.yaml') -PathType Leaf
$skillRoot = Split-Path -Parent $PSScriptRoot

$readCore = @(
  '.workflow/current.yaml',
  '.workflow/agents-init.yaml',
  '.workflow/task.yaml',
  '.workflow/open_threads.yaml',
  '.workflow/verification.yaml',
  '.workflow/thread_registry.yaml'
)

$lower = $Prompt.ToLowerInvariant()

$patterns = [ordered]@{
  menu = @('^\s*/?agents(-init)?\s*$', 'agents-init.*(menu|help)', '\bmenu\b', '\bhelp\b', 'what can.*agents-init.*do', 'how.*use.*agents-init', '\u600e\u4e48\u7528', '\u4f60\u80fd\u505a\u4ec0\u4e48', '\u5e2e\u6211\u770b\u600e\u4e48\u8d70', '\u6211\u4e0d\u77e5\u9053\u7528\u54ea\u4e2a\u547d\u4ee4')
  self_update = @('agents-init.*(self-update|update|upgrade)', '(self-update|update|upgrade).*agents-init', 'update.*skill', 'upgrade.*skill', 'skill.*\u66f4\u65b0', 'skill.*\u5347\u7ea7', 'skill.*\u65b0\u7248\u672c', 'pull.*latest.*agents-init', '\u66f4\u65b0.*agents-init', '\u5347\u7ea7.*agents-init', 'agents-init.*\u66f4\u65b0', 'agents-init.*\u5347\u7ea7')
  save = @('save-state', 'handoff', 'new session', 'compression', '\u538b\u7f29', '\u4ea4\u63a5', '\u65b0\u4f1a\u8bdd', '\u4fdd\u5b58\u72b6\u6001')
  recover = @('recover', 'where are we', 'current state', 'lost context', '\u6062\u590d', '\u73b0\u5728\u5230\u54ea', '\u5230\u54ea\u4e86', '\u4e0d\u8bb0\u5f97')
  ui = @('\bui\b', '\bux\b', 'visual', 'frontend', 'screenshot', '\u754c\u9762', '\u89c6\u89c9', '\u4ea4\u4e92', '\u524d\u7aef', '\u4e0d\u6ee1\u610f', '\u4e0d\u597d\u770b', '\u770b\u4e0d\u5230')
  sample = @('sample', 'reference', 'ozon', 'product research', 'image workflow', '\u7206\u54c1', '\u8d27\u6e90', '\u6837\u672c', '\u9009\u54c1', '\u5957\u56fe', '\u751f\u56fe', '\u53c2\u8003', '\u91c7\u96c6')
  salvage = @('salvage', 'failed branch', 'old branch', 'worktree', 'rewrite', 'second development', '\u4e8c\u5f00', '\u5931\u8d25', '\u65e7\u5206\u652f', '\u65e7\u9879\u76ee', '\u91cd\u6784', '\u91cd\u5199', '\u4ece0')
  worker = @('worker', 'subagent', 'sub-agent', 'thread', 'multi-session', 'receipt', 'parallel', '\u5b50\u4f1a\u8bdd', '\u591a\u4f1a\u8bdd', '\u8de8\u4f1a\u8bdd', '\u6d3e\u9001', '\u56de\u6267', '\u5e76\u884c', '\u5b50\u4ee3\u7406')
  maestro = @('maestro', 'ralph', 'delegate')
  maestro_skill = @('maestro skill', 'maestro skills', 'spec', 'knowhow', '\bkg\b', 'knowledge graph', 'wiki', 'domain', 'workspace', 'overlay', 'agent-msg', '\u77e5\u8bc6\u56fe\u8c31', '\u77e5\u8bc6\u5e93', '\u8bb0\u4f4f', '\u590d\u7528', '\u4ee5\u540e.*\u9075\u5b88')
  multimodel = @('claude', 'cc2', 'second view', 'second-view', 'multi-model', 'multimodel', 'other model', 'model review', '\u591a\u5927\u6a21\u578b', '\u7b2c\u4e8c\u5927\u6a21\u578b', '\u53cd\u9a73', '\u8ba9\s*claude', '\u627e\s*claude')
  model_config = @('configure.*claude', 'claude.*configure', 'config.*claude', 'claude.*config', 'multiple claude', 'multiple.*account', 'account.*claude', 'profile', 'model names.*change', 'role mapping', 'cli-tools\.json', 'CLAUDE_CONFIG_DIR', '\u914d\u7f6e.*claude', 'claude.*\u914d\u7f6e', '\u591a.*claude', '\u591a.*\u8d26\u53f7', '\u8d26\u53f7', '\u8fc7\u671f', '\u5c01\u53f7')
  model_failure = @('404', 'model.*not.*found', 'model.*unavailable', 'model.*inaccessible', 'opus.*fail', 'claude-opus-4\.7', '4\.7-thinking', 'claude\.exe', 'cc2.*works', 'default claude', 'wrong model', 'model.*wrong')
  opus = @('\bopus\b', '\b4\.8\b', 'claude.*opus', 'important plan debate')
  sonnet = @('\bsonnet\b', 'save quota', 'cheap claude', '\u7701\u989d\u5ea6')
  no_claude = @('no claude', 'codex only', '\u4e0d\u8981\s*claude')
  continuous_model = @('continuous reviewer', 'resume', 'keep reviewing', '\u6301\u7eed.*reviewer', '\u6301\u7eed.*claude')
  knowledge = @('maintain-knowledge', 'knowledge lifecycle', 'document lifecycle', 'document_lifecycle_receipt', 'documents.*piling', 'docs.*piling', 'unfinished docs', 'changed decisions', 'do not append.*summary', 'stop.*summary', 'archive.*receipts', 'supersede.*docs', 'promote.*knowhow', '\u6587\u6863', '\u6587\u4ef6.*\u5806', '\u6ca1\u5b8c\u6210', '\u672a\u5b8c\u6210', '\u51b3\u5b9a.*\u53d8', '\u51b3\u7b56.*\u53d8', '\u522b.*\u603b\u7ed3', '\u4e0d\u8981.*\u603b\u7ed3', '\u8ffd\u52a0\u603b\u7ed3', '\u5f52\u6863', '\u6536\u53e3', '\u788e\u7247', '\u6563\u843d', '\u672a\u89e3\u51b3', '\u8fc7\u671f', '\u53d6\u4ee3')
  main_orchestration = @('agents-init\s+main', 'agents init\s+main', 'main orchestration', 'multi-worktree', 'multi worktree', 'multiple worktrees', 'main per worktree', 'worktree orchestration', 'branch_plan', 'branch plan', 'completion_notice', 'completion notice', 'data_packet', 'data packet', 'chairman_brief', 'chairman brief', 'parked_waiting_next_packet', 'parked waiting next packet', 'task_packet', 'task packet', 'branch actor', 'branch actors', 'dynamic main', '\u603b\u7f16\u6392', '\u591a\u652f\u7ebf', '\u521b\u5efa\s*worktree', '\u652f\u7ebf.*\u4efb\u52a1\u5305', '\u8463\u4e8b\u957f.*\u7b80\u62a5')
  evidence_exhaustion = @('evidence_exhaustion', 'evidence exhaustion', 'evidence digest', 'negative_searches', 'negative searches', 'not_read_open_gap', 'not read open gap', 'rg alone', 'search exhaustion', 'context window', 'context compression', 'systemerror', 'crashpad', 'evidence not fully read', '\u8bc1\u636e.*\u6ca1\u8bfb\u5b8c', '\u8bc1\u636e.*\u7a77\u5c3d', '\u538b\u7f29.*\u8bc1\u636e', '\u627e\u4e0d\u5230.*\u4e0d\u7b49\u4e8e')
  direct = @('small clear task', 'direct', 'no maestro', '\u5c0f\u76ee\u6807', '\u5f88\u6e05\u695a', '\u76f4\u63a5', '\u4e0d\u9700\u8981\s*maestro')
  fuzzy = @('fuzzy', 'unclear', 'confused', 'clarify', 'grill', 'brainstorm', '\u6a21\u7cca', '\u8ff7\u832b', '\u6df7\u4e71', '\u4e0d\u61c2', '\u4e0d\u4f1a', '\u8dd1\u504f', '\u6f84\u6e05', '\u9700\u6c42')
  long = @('long task', 'many tasks', 'context', 'plan first', '\u957f\u4efb\u52a1', '\u591a\u4efb\u52a1', '\u4e0a\u4e0b\u6587', '\u62c6\u4efb\u52a1')
  context_reference = @('previous', 'previously', 'last time', 'already discussed', 'before', 'audit', 'localhost', '127\.0\.0\.1', '/image', '/canvas', 'screenshot', '\u4e4b\u524d', '\u4e0a\u6b21', '\u521a\u624d', '\u4e0d\u662f', '\u5df2\u7ecf', '\u5ba1\u8ba1', '\u878d\u5165', '\u622a\u56fe')
}

$matchedSignals = New-Object System.Collections.Generic.List[string]
foreach ($name in $patterns.Keys) {
  if (Test-AnyPattern $lower $patterns[$name]) {
    $matchedSignals.Add($name)
  }
}

if (Test-AnyPattern $lower $patterns['menu']) {
  $route = New-Route `
    -Name 'menu -> route-intent' `
    -Action 'Show the short natural-language Agents Init menu, then route the actual user request when provided.' `
    -Gate 'T0_menu_or_intake' `
    -Confidence 'high' `
    -Reason 'Prompt asks what agents-init can do or how to use it.' `
    -ReadFirst @('skill/agents-init/SKILL.md', '.workflow/agents-init.yaml') `
    -Commands @("powershell -NoProfile -ExecutionPolicy Bypass -File `"$skillRoot\scripts\init-agents.ps1`" -ProjectPath `"$project`" -Mode menu") `
    -MustNot @('Do not require the user to memorize commands.', 'Do not start implementation from a menu request.', 'After showing the menu, ask for or infer the actual task.')
} elseif (Test-AnyPattern $lower $patterns['self_update']) {
  $route = New-Route `
    -Name 'self-update -> optional project upgrade' `
    -Action 'Pull latest agents-init from GitHub, reinstall the local skill, then upgrade and validate the named project workflow only when requested.' `
    -Gate 'workflow_distribution_update' `
    -Confidence 'high' `
    -Reason 'Prompt asks to update or upgrade agents-init itself, not just the current project workflow.' `
    -ReadFirst @('skill/agents-init/SKILL.md', 'README.md') `
    -Commands @("powershell -NoProfile -ExecutionPolicy Bypass -File `"$env:USERPROFILE\.codex\skills\agents-init\scripts\update-agents-init.ps1`" -ProjectPath `"$project`"") `
    -MustNot @('Do not treat self-update as product semantic proof.', 'Do not ask v1/v2 as the first user-facing product question.', 'Do not upgrade business workflow files unless the project path is explicit or current project is clearly intended.')
} elseif ($hasWorkflow -and (Test-AnyPattern $lower $patterns['knowledge'])) {
  $route = New-Route `
    -Name 'maintain-knowledge' `
    -Action 'Recover workflow state, classify unfinished or stale artifacts, update active state, move unresolved items to open_threads, supersede changed decisions, promote stable lessons, and archive raw receipts.' `
    -Gate 'knowledge_lifecycle_triage' `
    -Confidence 'medium' `
    -Reason 'Prompt asks to clean up document pile-up, unfinished docs, changed decisions, scattered receipts, or summary sprawl.' `
    -ReadFirst ($readCore + @('.workflow/memory_points.yaml', '.workflow/archive/index.yaml')) `
    -Templates @('.workflow/templates/orchestration_decision.yaml', '.workflow/templates/document_lifecycle_receipt.yaml') `
    -Commands @(
      "powershell -NoProfile -ExecutionPolicy Bypass -File `"$skillRoot\scripts\recover-agents.ps1`" -ProjectPath `"$project`"",
      "powershell -NoProfile -ExecutionPolicy Bypass -File `"$skillRoot\scripts\invoke-maestro-skill.ps1`" -ProjectPath `"$project`" -Skill search -Query <task-relevant-query> -All -Json",
      "powershell -NoProfile -ExecutionPolicy Bypass -File `"$skillRoot\scripts\invoke-maestro-skill.ps1`" -ProjectPath `"$project`" -Skill knowhow -Action search -Query <reusable-lesson-query> -Json",
      "powershell -NoProfile -ExecutionPolicy Bypass -File `"$skillRoot\scripts\invoke-maestro-skill.ps1`" -ProjectPath `"$project`" -Skill spec -Action search -Query <stable-rule-query> -Json"
    ) `
    -MustNot @('Do not append another summary before classifying artifacts.', 'Do not treat route-intent as semantic proof.', 'Do not delete or archive without preserving restore or trace references.', 'Do not call the workflow healthy while open_threads warnings remain.')
} elseif ($hasWorkflow -and (Test-AnyPattern $lower $patterns['main_orchestration'])) {
  $route = New-Route `
    -Name 'main-orchestration-intake' `
    -Action 'Recover project state, analyze goal/object/module boundaries, then propose or resume dynamic main/multi-worktree orchestration with task_packet, branch_plan, completion_notice, data_packet, chairman_brief, and parked_waiting_next_packet lifecycle.' `
    -Gate 'main_orchestration_intake' `
    -Confidence 'high' `
    -Reason 'Prompt mentions dynamic main, multi-worktree orchestration, branch packets, completion notices, data packets, chairman brief, or parked branch state.' `
    -ReadFirst ($readCore + @('references/main-worktree-orchestration.md', 'references/codex-thread-protocol.md')) `
    -Templates @('.workflow/templates/orchestration_decision.yaml', '.workflow/templates/task_packet.yaml', '.workflow/templates/branch_plan.yaml', '.workflow/templates/branch_completion_notice.yaml', '.workflow/templates/cross_project_data_packet.yaml', '.workflow/templates/chairman_brief.yaml', '.workflow/templates/parked_waiting_next_packet.yaml') `
    -Commands @(
      "powershell -NoProfile -ExecutionPolicy Bypass -File `"$skillRoot\scripts\recover-agents.ps1`" -ProjectPath `"$project`"",
      "Write or update task_packet / branch_plan / completion_notice / data_packet / chairman_brief artifacts before changing branch state."
    ) `
    -MustNot @('Do not create worktrees before recovery, goal clarification, and object/module boundary analysis.', 'Do not make agents-init main mandatory; it is an optional shortcut.', 'Do not hardcode Ozon B/S/C lanes as generic agents-init rules.', 'Do not treat completion_notice, data_packet, valid=true, route-intent, or started workers as final proof.')
} elseif ($hasWorkflow -and (Test-AnyPattern $lower $patterns['evidence_exhaustion'])) {
  $route = New-Route `
    -Name 'evidence-exhaustion-guardrail' `
    -Action 'Run the Context Hygiene And Evidence Exhaustion guardrail only for the named high-risk scope: record methods, positive evidence, negative_searches, not_read_open_gap, excluded noise, and proof boundaries before relying on absence claims.' `
    -Gate 'evidence_exhaustion_guardrail' `
    -Confidence 'high' `
    -Reason 'Prompt or recovered state signals context compression, evidence-heavy work, absence claims, system errors, or incomplete evidence reading.' `
    -ReadFirst ($readCore + @('references/context-hygiene-and-evidence-exhaustion.md')) `
    -Templates @('.workflow/templates/evidence_exhaustion_check.yaml', '.workflow/templates/evidence_digest.yaml') `
    -MustNot @('rg alone is not evidence exhaustion.', 'Do not treat valid=true, started workers, listed tools, or route-intent recommendations as live proof.', 'Do not put raw evidence piles into model context when an indexed artifact or digest is safer.')
} elseif (Test-AnyPattern $lower $patterns['maestro_skill']) {
  $route = New-Route `
    -Name 'invoke-maestro-skill' `
    -Action 'Use non-Claude Maestro surfaces in two steps: first capture CLI knowledge anchors from search/spec/knowhow/wiki/KG/domain/workspace/msg/overlay/delegate-config, then verify the project-level Maestro Codex skill registry, read the selected project skill SKILL.md, and either apply it in-context or record why it is blocked.' `
    -Gate 'maestro_skill_context_or_lifecycle' `
    -Confidence 'high' `
    -Reason 'Prompt asks for Maestro skills, reusable memory/rules, KG/search, wiki/domain/workspace, or cross-agent coordination surfaces.' `
    -ReadFirst ($readCore + @('references/maestro-routing.md', 'references/main-agent-orchestration.md')) `
    -Templates @('.workflow/templates/orchestration_decision.yaml', '.workflow/templates/document_lifecycle_receipt.yaml') `
    -Commands @(
      "powershell -NoProfile -ExecutionPolicy Bypass -File `"$skillRoot\scripts\invoke-maestro-skill.ps1`" -ProjectPath `"$project`" -Skill search -Query <task-relevant-query> -All -Json",
      "powershell -NoProfile -ExecutionPolicy Bypass -File `"$skillRoot\scripts\invoke-maestro-skill.ps1`" -ProjectPath `"$project`" -Skill kg -Action search -Query <code-or-object-query> -Json",
      "powershell -NoProfile -ExecutionPolicy Bypass -File `"$skillRoot\scripts\invoke-maestro-skill.ps1`" -ProjectPath `"$project`" -Skill delegate-config -Json",
      "maestro ralph skills --platform codex --json --quiet",
      "Read the selected project skill SKILL.md, e.g. .codex/skills/maestro-grill/SKILL.md or .codex/skills/maestro-next/SKILL.md, before claiming project-level Maestro skill orchestration."
    ) `
    -MustNot @('Do not confuse Maestro skills with Claude delegate.', 'Do not claim multi-model review from search/spec/knowhow output.', 'Do not skip main-agent synthesis of proves and does_not_prove.', 'Registry enumeration alone is insufficient; file existence or recommendation is not execution.', 'Do not treat maestro grill --help or maestro next --help generic CLI output as proof that project Codex skills ran.')
} elseif ($hasWorkflow -and (Test-AnyPattern $lower $patterns['context_reference'])) {
  $contextTemplates = @('.workflow/templates/orchestration_decision.yaml', '.workflow/templates/multi_perspective_review.yaml', '.workflow/memory_points.yaml')
  if (Test-AnyPattern $lower $patterns['multimodel']) {
    $contextTemplates += @('.workflow/templates/multi_model_context_packet.md', '.workflow/templates/model_review_receipt.yaml')
  }
  $route = New-Route `
    -Name 'context-retrieve -> clarify' `
    -Action 'Recover workflow, memory points, local docs, and relevant browser/localhost anchors before asking clarification questions.' `
    -Gate 'T0_context_recovery_to_T1_clarify' `
    -Confidence 'high' `
    -Reason 'Prompt references prior work, audits, pages, ports, screenshots, or direction corrections.' `
    -ReadFirst ($readCore + @('.workflow/memory_points.yaml', '.workflow/model_policy.yaml')) `
    -Templates $contextTemplates `
    -Commands @("powershell -NoProfile -ExecutionPolicy Bypass -File `"$skillRoot\scripts\recover-agents.ps1`" -ProjectPath `"$project`"") `
    -MustNot @('Do not ask clarification from a blank slate.', 'Do not treat this script as semantic proof.', 'Do not implement before citing recovered anchors.', 'Do not ask downstream questions before root_diagnosis states recovered mainline vs current contradiction.', 'Do not ask for confirmation before disclosing visible page/route/workflow consequences.', 'Do not claim Claude or multi-model review happened without model output and receipt.')
} elseif (-not $hasWorkflow) {
  $route = New-Route `
    -Name 'init-or-adopt' `
    -Action 'Run init-agents.ps1 -Mode auto, then recover before coding.' `
    -Gate 'T0_intake' `
    -Confidence 'high' `
    -Reason 'Project workflow state is missing.' `
    -Commands @("powershell -NoProfile -ExecutionPolicy Bypass -File `"$skillRoot\scripts\init-agents.ps1`" -ProjectPath `"$project`" -Mode auto") `
    -MustNot @('Do not overwrite existing AGENTS.md or product docs automatically.')
} elseif (Test-AnyPattern $lower $patterns['save']) {
  $route = New-Route `
    -Name 'save-state' `
    -Action 'Write a recovery brief before context compression or handoff.' `
    -Gate 'handoff' `
    -Confidence 'high' `
    -Reason 'Prompt mentions compression, handoff, or new session continuity.' `
    -ReadFirst $readCore `
    -Commands @("powershell -NoProfile -ExecutionPolicy Bypass -File `"$skillRoot\scripts\save-state.ps1`" -ProjectPath `"$project`"") `
    -Templates @('.workflow/templates/session_recovery_brief.md') `
    -MustNot @('Do not rely on conversation memory as the only recovery source.')
} elseif (Test-AnyPattern $lower $patterns['recover']) {
  $route = New-Route `
    -Name 'recover' `
    -Action 'Recover goal, gate, evidence, open threads, and next action.' `
    -Gate 'T0_intake' `
    -Confidence 'high' `
    -Reason 'Prompt asks for current state or lost context recovery.' `
    -ReadFirst $readCore `
    -Commands @("powershell -NoProfile -ExecutionPolicy Bypass -File `"$skillRoot\scripts\recover-agents.ps1`" -ProjectPath `"$project`"")
} elseif (Test-AnyPattern $lower $patterns['salvage']) {
  $route = New-Route `
    -Name 'blueprint -> salvage -> insertion-plan' `
    -Action 'Map requirement, classify old assets, then define insertion points before implementation.' `
    -Gate 'T2_blueprint_to_T4_insertion_plan' `
    -Confidence 'high' `
    -Reason 'Prompt describes old project, failed second-development, rewrite, or worktree salvage.' `
    -ReadFirst ($readCore + @('references/adoption-salvage.md')) `
    -Templates @('.workflow/templates/orchestration_decision.yaml', '.workflow/templates/multi_perspective_review.yaml', '.workflow/templates/adoption_salvage_report.yaml', '.workflow/templates/plan_pm_fde.yaml') `
    -MustNot @('Do not copy an old rule wall blindly.', 'Do not write product code before salvage and insertion plan.')
} elseif (Test-AnyPattern $lower $patterns['ui']) {
  $route = New-Route `
    -Name 'grill -> ux_issue -> visible evidence' `
    -Action 'Clarify UI dissatisfaction and define visible acceptance before coding.' `
    -Gate 'T1_clarify_or_T5_visible_slice' `
    -Confidence 'high' `
    -Reason 'Prompt mentions UI, UX, visual, frontend, screenshot, or dissatisfaction.' `
    -ReadFirst $readCore `
    -Templates @('.workflow/templates/orchestration_decision.yaml', '.workflow/templates/multi_perspective_review.yaml', '.workflow/templates/ux_issue.yaml', '.workflow/templates/verification_receipt.yaml') `
    -MustNot @('Do not treat backend tests as UI acceptance.', 'Do not implement before acceptance criteria are known.') `
    -HumanGate $true
} elseif (Test-AnyPattern $lower $patterns['no_claude']) {
  $route = New-Route `
    -Name 'skip-claude-record-policy' `
    -Action 'Do not call Claude. Recover context and record that multi-model review was intentionally skipped for this task.' `
    -Gate 'model_review_skipped' `
    -Confidence 'high' `
    -Reason 'Prompt explicitly disables Claude or requests Codex-only work.' `
    -ReadFirst ($readCore + @('.workflow/model_policy.yaml')) `
    -Templates @('.workflow/templates/orchestration_decision.yaml') `
    -MustNot @('Do not call cc2.', 'Do not claim a multi-model review happened.')
} elseif (((Test-AnyPattern $lower $patterns['model_config']) -or (Test-AnyPattern $lower $patterns['model_failure'])) -and -not (Test-AnyPattern $lower $patterns['no_claude'])) {
  $route = New-Route `
    -Name 'multi-model-config-gate' `
    -Action 'Inspect Maestro and Claude routing configuration, distinguish cc2 wrapper from default claude and Maestro delegate, report the exact failing route/model, and prove raw output with smoke before claiming integration.' `
    -Gate 'multi_model_configuration_policy' `
    -Confidence 'high' `
    -Reason 'Prompt asks about configuring Claude, multiple accounts/profiles, model drift, route failure, 404, role mapping, or durable multi-model routing.' `
    -ReadFirst ($readCore + @('.workflow/model_policy.yaml', 'references/maestro-routing.md', 'references/multi-model-shared-context.md', 'references/multi-model-role-policy.md')) `
    -Templates @('.workflow/templates/orchestration_decision.yaml', '.workflow/templates/delegate_receipt.yaml', '.workflow/templates/model_review_receipt.yaml') `
    -Commands @('maestro config delegate show --json', 'powershell -NoProfile -ExecutionPolicy Bypass -File <skill>\scripts\doctor-agents.ps1 -ProjectPath <project> -Json') `
    -MustNot @('Do not silently edit global config.', 'Do not switch Claude profiles without explicit user confirmation.', 'Do not hardcode dated concrete model names unless the local tool requires it.', 'Do not claim role routing uses Claude when roles still map to Codex.', 'Do not trust Maestro completed metadata without raw task-relevant output.', 'Do not treat default claude or Maestro failure as cc2 failure.')
} elseif ((Test-AnyPattern $lower $patterns['multimodel']) -and -not (Test-AnyPattern $lower $patterns['no_claude'])) {
  $modelAlias = if (Test-AnyPattern $lower $patterns['sonnet']) { 'sonnet' } else { 'opus' }
  $executionMode = if (Test-AnyPattern $lower $patterns['continuous_model']) { 'capturable_cli_continuous' } else { 'capturable_cli_one_shot' }
  $maestroCommand = "powershell -NoProfile -ExecutionPolicy Bypass -File `"$skillRoot\scripts\invoke-claude-review.ps1`" -ProjectPath `"$project`" -Task <bounded-analysis-task> -Json"
  $fallbackCommand = "cc2 --safe-mode -p <compact-packet> --model $modelAlias --output-format json" + $(if ($executionMode -eq 'capturable_cli_one_shot') { ' --no-session-persistence' } else { ' --resume <session_id>' })
  $route = New-Route `
    -Name 'multi-model-packet -> claude-review' `
    -Action "Create a compact recovered context packet or bounded delegate task, request Claude model alias '$modelAlias', prefer proven Maestro delegate raw output, fallback to cc2 only when Maestro is inconclusive, and ingest a model review receipt." `
    -Gate 'second_view_review' `
    -Confidence 'high' `
    -Reason 'Prompt explicitly asks for Claude, cc2, opus/sonnet, another model, second-view critique, or model-level debate.' `
    -ReadFirst ($readCore + @('.workflow/model_policy.yaml', 'references/multi-model-shared-context.md', 'references/multi-model-role-policy.md')) `
    -Templates @('.workflow/templates/multi_model_context_packet.md', '.workflow/templates/model_review_receipt.yaml', '.workflow/templates/orchestration_decision.yaml') `
    -Commands @($maestroCommand, $fallbackCommand) `
    -MustNot @('Do not route routine implementation to Claude by default.', 'Do not claim multi-model proof unless a non-Codex model actually returned raw output.', 'Do not resume an old model session without a bounded reason.', 'Do not dump all recovered context into cc2.', 'Record requested_model_alias and actual model reported by the tool.', 'Treat cc2 as profile/alias fallback, not the default lifecycle.')
} elseif (Test-AnyPattern $lower $patterns['sample']) {
  $route = New-Route `
    -Name 'sample_decision -> research -> human gate' `
    -Action 'Define sample/source criteria and evidence boundary before implementation.' `
    -Gate 'T1_clarify_or_T2_blueprint' `
    -Confidence 'high' `
    -Reason 'Prompt mentions samples, products, sources, references, image workflow, e-commerce/Ozon case context, or product research.' `
    -ReadFirst $readCore `
    -Templates @('.workflow/templates/orchestration_decision.yaml', '.workflow/templates/multi_perspective_review.yaml', '.workflow/templates/sample_decision.yaml', '.workflow/templates/image_quality_review.yaml') `
    -MustNot @('Do not let a worker choose final samples.', 'Do not claim seller-ready or image quality without user-visible evidence.') `
    -HumanGate $true
} elseif (Test-AnyPattern $lower $patterns['worker']) {
  $route = New-Route `
    -Name 'dispatch-worker' `
    -Action 'Create or message one bounded worker with a receipt contract.' `
    -Gate 'worker_dispatch' `
    -Confidence 'medium' `
    -Reason 'Prompt asks for multi-session, worker, parallel, receipt, or subagent work.' `
    -ReadFirst ($readCore + @('references/codex-thread-protocol.md')) `
    -Templates @('.workflow/templates/task_brief.yaml', '.workflow/templates/worker_receipt.yaml') `
    -Commands @("powershell -NoProfile -ExecutionPolicy Bypass -File `"$skillRoot\scripts\make-worker-prompt.ps1`" -ProjectPath `"$project`" -TaskId <task-id> -Task <task> -Scope <scope>") `
    -MustNot @('Do not let the worker decide product direction.', 'Do not proceed until the main agent ingests the receipt.')
} elseif (Test-AnyPattern $lower $patterns['maestro']) {
  $route = New-Route `
    -Name 'route-maestro' `
    -Action 'Choose direct, worker, Maestro delegate, or Ralph based on the current gate.' `
    -Gate 'route_selection' `
    -Confidence 'medium' `
    -Reason 'Prompt mentions Maestro, Ralph, or delegate.' `
    -ReadFirst ($readCore + @('references/maestro-routing.md')) `
    -Templates @('.workflow/templates/orchestration_decision.yaml', '.workflow/templates/multi_perspective_review.yaml', '.workflow/templates/delegate_receipt.yaml') `
    -MustNot @('Do not auto-advance Ralph across UI, sample, generated-image, or external-write gates.') `
    -HumanGate $true
} elseif (Test-AnyPattern $lower $patterns['multimodel']) {
  $route = New-Route `
    -Name 'multi-model-packet -> claude-review' `
    -Action 'Create a compact recovered context packet, ask one bounded Claude/CLI model question, capture output, and ingest a model review receipt.' `
    -Gate 'second_view_review' `
    -Confidence 'medium' `
    -Reason 'Prompt asks for Claude, another model, second-view critique, or model-level debate.' `
    -ReadFirst ($readCore + @('references/multi-model-shared-context.md', 'references/multi-model-role-policy.md')) `
    -Templates @('.workflow/templates/multi_model_context_packet.md', '.workflow/templates/model_review_receipt.yaml', '.workflow/templates/orchestration_decision.yaml') `
    -MustNot @('Do not route routine implementation to Claude by default.', 'Do not claim multi-model proof unless a non-Codex model actually returned output.', 'Do not resume an old model session without a bounded reason.')
} elseif ((Test-AnyPattern $lower $patterns['direct']) -and -not (Test-AnyPattern $lower ($patterns['fuzzy'] + $patterns['long'] + $patterns['ui'] + $patterns['sample']))) {
  $route = New-Route `
    -Name 'direct' `
    -Action 'Do the small clear task directly after stating completion standard and verification.' `
    -Gate 'direct_execution' `
    -Confidence 'medium' `
    -Reason 'Prompt says the goal is small or clear and does not contain risky gate signals.' `
    -ReadFirst @('.workflow/current.yaml') `
    -MustNot @('Do not force Maestro/Ralph overhead for a clear small task.')
} elseif ((Test-AnyPattern $lower $patterns['long']) -or (Test-AnyPattern $lower $patterns['fuzzy'])) {
  $route = New-Route `
    -Name 'grill -> brainstorm -> plan' `
    -Action 'Restate goal, list uncertainty, ask at most 1-3 questions, then create PM/FDE plan.' `
    -Gate 'T1_clarify_to_T2_blueprint' `
    -Confidence 'medium' `
    -Reason 'Prompt is fuzzy, long, or context-heavy.' `
    -ReadFirst $readCore `
    -Templates @('.workflow/templates/orchestration_decision.yaml', '.workflow/templates/multi_perspective_review.yaml', '.workflow/templates/task_brief.yaml', '.workflow/templates/plan_pm_fde.yaml') `
    -MustNot @('Do not implement first.', 'Do not ask the user to repeat the full history.')
} else {
  $route = New-Route `
    -Name 'clarify' `
    -Action 'Restate the likely goal, list uncertainty, and ask at most 1-3 questions.' `
    -Gate 'T1_clarify' `
    -Confidence 'low' `
    -Reason 'No reliable route signal matched.' `
    -ReadFirst $readCore `
    -Templates @('.workflow/templates/task_brief.yaml') `
    -MustNot @('Do not pretend keyword routing is certainty.')
}

$result = [ordered]@{
  project = $project
  prompt = $Prompt
  advisory = 'Keyword routing is only a first pass. The main agent must override it when project state or user intent says otherwise.'
  workflow_present = $hasWorkflow
  matched_signals = @($matchedSignals)
  result = $route
  next_main_agent_move = if ($route.human_gate) {
    'Pause for acceptance criteria or user-visible evidence before implementation.'
  } elseif ($route.route -eq 'direct') {
    'State completion standard and verification, then execute.'
  } else {
    'Recover or update workflow state before implementation.'
  }
}

if ($Json) {
  $result | ConvertTo-Json -Depth 8
  exit 0
}

Write-Output "Agents Init Route"
Write-Output "Project: $project"
Write-Output "Route: $($route.route)"
Write-Output "Action: $($route.recommended_action)"
Write-Output "Gate: $($route.gate)"
Write-Output "Confidence: $($route.confidence)"
Write-Output "Reason: $($route.reason)"
Write-Output "Next: $($result.next_main_agent_move)"
if ($route.must_not.Count -gt 0) {
  Write-Output ""
  Write-Output "Must not:"
  foreach ($item in $route.must_not) { Write-Output "- $item" }
}
