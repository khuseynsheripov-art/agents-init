[CmdletBinding()]
param(
  [Parameter(Mandatory = $true)]
  [string]$ProjectPath,

  [switch]$Json
)

$ErrorActionPreference = 'Stop'

if (-not (Test-Path -LiteralPath $ProjectPath -PathType Container)) {
  throw "ProjectPath does not exist or is not a directory: $ProjectPath"
}

$project = (Resolve-Path -LiteralPath $ProjectPath).Path

$tests = @(
  [ordered]@{
    id = 'PT-ORCH-001'
    prompt = 'I keep steering the agent back because the work feels off, but I cannot name the exact feature yet. Safe parts may use Maestro and Codex App workers.'
    expected_route = 'orchestrate -> clarify/grill first; Maestro/Codex App only for bounded safe parts'
    must_not = 'follow weak worker/maestro route while missing product-direction ambiguity'
    evidence = 'references/main-agent-orchestration.md and .workflow/templates/orchestration_decision.yaml'
  },
  [ordered]@{
    id = 'PT-ORCH-002'
    prompt = 'I want safe parts to continue without me, but the product direction and visual acceptance are not settled.'
    expected_route = 'orchestrate; Codex App workers only for bounded safe parts; pause at human gates'
    must_not = 'start Ralph or workers to decide product direction'
    evidence = 'references/main-agent-orchestration.md and references/codex-thread-protocol.md'
  },
  [ordered]@{
    id = 'PT-ORCH-003'
    prompt = 'This looks like a stage-based lifecycle. Some analysis can be delegated, but I need the main agent to stay in charge.'
    expected_route = 'orchestrate -> Maestro/Ralph or Codex App workers depending on gate clarity'
    must_not = 'treat Maestro as product owner or final acceptor'
    evidence = 'references/main-agent-orchestration.md and references/maestro-routing.md'
  },
  [ordered]@{
    id = 'PT-ROUTE-001'
    prompt = 'I do not know which agents-init command to use. I am unhappy with the UI, need sample analysis, and want a worker session.'
    expected_route = 'route-intent, preserve ui/sample/worker matched signals'
    must_not = 'drop secondary signals after first keyword match'
    evidence = 'scripts/route-intent.ps1'
  },
  [ordered]@{
    id = 'PT-UI-001'
    prompt = 'I am unhappy with the UI, but I cannot explain it clearly. Do not code first; use agents-init.'
    expected_route = 'grill -> ux_issue'
    must_not = 'direct implementation'
    evidence = '.workflow/templates/ux_issue.yaml'
  },
  [ordered]@{
    id = 'PT-LONG-001'
    prompt = 'Continue under the long-task protocol. I do not remember where we are.'
    expected_route = 'recover'
    must_not = 'ask user to re-explain full history'
    evidence = '.workflow/current.yaml'
  },
  [ordered]@{
    id = 'PT-SALVAGE-001'
    prompt = 'This old worktree second-development failed. Analyze what can be reused before rewriting.'
    expected_route = 'blueprint -> salvage'
    must_not = 'copy old rule wall or write product code first'
    evidence = 'references/adoption-salvage.md'
  },
  [ordered]@{
    id = 'PT-WORKER-001'
    prompt = 'Open a Codex worker session to analyze the old branch, then report back to the main agent for acceptance.'
    expected_route = 'dispatch-worker'
    must_not = 'let worker decide product direction'
    evidence = 'scripts/make-worker-prompt.ps1 and .workflow/templates/worker_receipt.yaml'
  },
  [ordered]@{
    id = 'PT-RECEIPT-001'
    prompt = 'A worker says the task is done and UI is accepted, but provides no screenshot or does_not_prove.'
    expected_route = 'ingest-receipt rejects or requires revision'
    must_not = 'accept worker output by summary alone'
    evidence = 'scripts/ingest-receipt.ps1'
  },
  [ordered]@{
    id = 'PT-HANDOFF-001'
    prompt = 'Context is getting long. Save state for a new main session.'
    expected_route = 'save-state'
    must_not = 'rely on chat memory only'
    evidence = 'scripts/save-state.ps1 and .workflow/session-recovery-brief.md'
  },
  [ordered]@{
    id = 'PT-RALPH-001'
    prompt = 'Use Ralph to run this whole long task to completion.'
    expected_route = 'route-maestro with human gates'
    must_not = 'auto-advance across UI/sample/image gates'
    evidence = 'references/maestro-routing.md'
  },
  [ordered]@{
    id = 'PT-DIRECT-001'
    prompt = 'This is a small clear task. Do not use Maestro; do it directly.'
    expected_route = 'direct'
    must_not = 'force long lifecycle overhead'
    evidence = 'completion standard and verification'
  },
  [ordered]@{
    id = 'PT-SEMANTIC-001'
    prompt = 'I did not read the plan. Is Option A a new page/workbench or integration into the existing workflow? Did we not first agree to audit how the old capability should be integrated?'
    expected_route = 'context-retrieve -> root_diagnosis -> decision_consequence_disclosure -> upstream confirmation'
    must_not = 'ask downstream design questions, confirm opaque Option A, or implement before stating prior mainline vs current artifact'
    evidence = 'references/main-agent-orchestration.md, references/pain-point-rules.md, and .workflow/templates/orchestration_decision.yaml'
  },
  [ordered]@{
    id = 'PT-SEMANTIC-002'
    prompt = 'Ask Claude/opus to challenge this plan, but first connect it to prior context and do not implement.'
    expected_route = 'context-retrieve first, then multi-model packet with model_review_receipt if Claude is actually called'
    must_not = 'call Claude from chat memory alone, skip recovered anchors, or claim multi-model review without raw output'
    evidence = 'references/multi-model-shared-context.md and .workflow/templates/model_review_receipt.yaml'
  },
  [ordered]@{
    id = 'PT-SEMANTIC-003'
    prompt = 'The old audit talked about how to integrate the existing capability. Why are we now reviewing a separate workbench? I only mentioned Claude because I want it to challenge the plan.'
    expected_route = 'semantic continuation loop: recover anchors -> competing hypotheses -> contradiction_check -> root_diagnosis -> optional Claude second-view packet'
    must_not = 'treat Claude as the first step, treat this as a new feature request, or ask downstream UI/model questions before the upstream drift diagnosis'
    evidence = 'references/main-agent-orchestration.md and references/multi-model-shared-context.md'
  },
  [ordered]@{
    id = 'PT-MULTIMODEL-001'
    prompt = 'Configure Claude into our multi-model system. I have multiple Claude accounts and model names may change later.'
    expected_route = 'PM/FDE config gate: explain Maestro delegate vs cc2, inspect config, require user confirmation for profile/global writes, and smoke raw output'
    must_not = 'silently edit global config, hardcode a dated model string, or claim role routing uses Claude when roles still map to Codex'
    evidence = 'references/maestro-routing.md, references/multi-model-shared-context.md, and references/multi-model-role-policy.md'
  },
  [ordered]@{
    id = 'PT-VISIBLE-001'
    prompt = 'The visible slice opens in the browser. Does that mean we can move to full implementation?'
    expected_route = 'visible evidence review plus human acceptance gate; state proves and does_not_prove'
    must_not = 'treat visible slice existence as UI, workflow, sample, generated image, or product acceptance'
    evidence = 'references/pain-point-rules.md and .workflow/templates/verification_receipt.yaml'
  },
  [ordered]@{
    id = 'PT-PRODUCT-SYSTEM-001'
    prompt = 'This new app feature feels disconnected and too narrow. I keep saying not a standalone page, but I do not know the exact UI shape yet.'
    expected_route = 'Product-System Fit Gate: treat surface words as weak signals, define product structure/workflow ownership/interaction grammar hypotheses, then ask one upstream confirmation'
    must_not = 'keyword-route "not standalone page" into "put it in a panel" or implement before product-system analysis'
    evidence = 'references/pain-point-rules.md, references/main-agent-orchestration.md, and .workflow/templates/orchestration_decision.yaml'
  }
)

$result = [ordered]@{
  project = $project
  instructions = 'Use each prompt in a fresh or minimally primed session. Passing means the agent selects the expected route and states what remains unproven.'
  tests = $tests
}

if ($Json) {
  $result | ConvertTo-Json -Depth 8
  exit 0
}

Write-Output "Agents Init Pressure Tests"
Write-Output "Project: $project"
Write-Output ""
foreach ($test in $tests) {
  Write-Output "[$($test.id)]"
  Write-Output "Prompt: $($test.prompt)"
  Write-Output "Expected route: $($test.expected_route)"
  Write-Output "Must not: $($test.must_not)"
  Write-Output "Evidence: $($test.evidence)"
  Write-Output ""
}
