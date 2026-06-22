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
    id = 'PT-WORKER-WAIT-001'
    prompt = 'I opened a worker for a bounded analysis. Do not keep recalling me every 30 seconds; normally wait until the worker finishes unless I ask for status.'
    expected_route = 'dispatch-worker -> wait for natural completion or user/status event -> ingest receipt'
    must_not = 'create fixed-interval recall/polling/nudge loops or count started worker work as evidence'
    evidence = 'references/codex-thread-protocol.md Waiting And Status Updates and docs/dev-os/multi-codex-session-mode.md Waiting Policy'
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
  },
  [ordered]@{
    id = 'PT-PRODUCT-SYSTEM-002'
    prompt = 'Your direction is right but still not enough. You said it should not be a standalone page and should go into the existing editor/right panel, but I still do not see that you analyzed the original project, the menu/panel grammar, generation chain, or first slice acceptance.'
    expected_route = 'Product-System Fit Gate stays open: must cite original product anchors, native interaction grammar, capability reuse plan, candidate insertion points, first visible slice acceptance, and does_not_prove before implementation'
    must_not = 'treat a correct direction summary as sufficient, ask only for confirmation, or claim multi-perspective/Claude analysis without design_debate_receipt'
    evidence = 'references/main-agent-orchestration.md Correct Direction Is Not Enough, references/pain-point-rules.md, and .workflow/templates/design_debate_receipt.yaml'
  },
  [ordered]@{
    id = 'PT-PRODUCT-SYSTEM-003'
    prompt = '/agents init User asks: is this the previous analysis, is it canvas page vs image page, or is it a new page? I do not understand.'
    expected_route = 'context-retrieve -> user-visible Product-System receipt -> upstream confirmation. The answer must show recovered anchors, root diagnosis, PFIT status, consequence, and one question.'
    must_not = 'answer only with prose that says /canvas/ozon-suite is a workbench and /canvas/[id] right panel is final; that is summary_only_failure unless anchors/PFIT/does_not_prove are visible'
    evidence = 'references/case-studies/ozon-canvas.md Screenshot Failure Update and references/main-agent-orchestration.md User-Visible Product-System Receipt'
  },
  [ordered]@{
    id = 'PT-INTEGRATION-FIT-001'
    prompt = 'You added a global navigation item and a first-level workbench, but I asked for integration into the existing editor workflow. Do not treat access or placement as integration.'
    expected_route = 'Product-System Fit Gate with integration_fit blocked or summary_only_failure; must distinguish global_nav, first_level_workspace, and editor-internal integration.'
    must_not = 'claim integration passed because a top-level route, tab, menu item, or workbench exists'
    evidence = 'references/main-agent-orchestration.md surface level matrix and .workflow/templates/orchestration_decision.yaml integration_fit'
  },
  [ordered]@{
    id = 'PT-INTEGRATION-FIT-002'
    prompt = 'A separate suite workbench already runs, but I want the capability to reuse the original editor nodes, right panel, assets, and generation chain. Analyze integration before implementation.'
    expected_route = 'Product-System Fit Gate: list 2-3 editor-native insertion points, object/workflow owners, reused capabilities, anti-sidecar risks, first visible slice, and does_not_prove.'
    must_not = 'continue the workbench as the formal product path without naming the native editor handoff and object/data contract'
    evidence = 'references/pain-point-rules.md placement-vs-integration and .workflow/templates/orchestration_decision.yaml integration_fit'
  },
  [ordered]@{
    id = 'PT-INTEGRATION-FIT-003'
    prompt = 'The answer now separates /canvas/ozon-suite as prototype workbench, /image as reusable capability, and /canvas/[id] as the final editor surface. It proposes a topbar Ozon Suite button, right-side panel, normal image node, and metadata. Is that enough to proceed?'
    expected_route = 'Still Product-System Fit Gate, not implementation: produce a compact PFIT/Integration receipt with recovered anchors, target_surface_level, object_owner, workflow_owner, capability_reuse contract, native interaction grammar, anti-sidecar risk, first_visible_slice, does_not_prove, and one upstream confirmation.'
    must_not = 'claim integration passed merely because the three surfaces are separated or because topbar + right panel + node metadata sounds editor-native'
    evidence = 'references/case-studies/ozon-canvas.md Screenshot Failure Update, references/main-agent-orchestration.md User-Visible Product-System Receipt, and .workflow/templates/orchestration_decision.yaml integration_fit'
  },
  [ordered]@{
    id = 'PT-KNOWLEDGE-LIFECYCLE-001'
    prompt = 'We have many unfinished docs and decisions changed while talking. Do not append another summary. Tell me what is active, unresolved, superseded, archived, and what gets promoted.'
    expected_route = 'maintain-knowledge -> document_lifecycle_receipt -> update current/task/open_threads/memory_points/archive with active, unresolved, superseded, archived, promoted, and rejected classifications.'
    must_not = 'write another plan or summary without closing, superseding, archiving, or promoting stale artifacts'
    evidence = 'references/workflow-schema.md Document Triage Receipt, references/usage-playbook.md Document Maintenance Pattern, and .workflow/templates/document_lifecycle_receipt.yaml'
  },
  [ordered]@{
    id = 'PT-MAESTRO-SKILL-ORCH-001'
    prompt = 'I am fuzzy. Use Maestro Grill/knowledge/KG to review whether agents-init really orchestrates Maestro skills and Codex App multi-session work. Do not make me hand-type commands.'
    expected_route = 'agents-init recover -> Maestro CLI knowledge anchors -> project-level Maestro Codex skill verification -> read the selected project skill SKILL.md -> bounded in-context Grill/Next action or explicit blocked receipt.'
    must_not = 'stop after calling agents-init, list .codex/skills, or run only maestro ralph skills; Registry enumeration alone is insufficient and maestro grill CLI help is not proof that maestro-grill ran.'
    evidence = 'SKILL.md Maestro And Threads, references/maestro-routing.md Project-Level Maestro Codex Skills, and .workflow/scratch/agents-init-maestro-skill-new-thread-smoke.md'
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
