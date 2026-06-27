[CmdletBinding()]
param(
  [string]$RepoRoot = '',
  [string]$SampleProject = ''
)

$ErrorActionPreference = 'Stop'

if ([string]::IsNullOrWhiteSpace($RepoRoot)) {
  $RepoRoot = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot '..\..\..')).Path
}

function Assert-True {
  param(
    [Parameter(Mandatory = $true)][bool]$Condition,
    [Parameter(Mandatory = $true)][string]$Message
  )
  if (-not $Condition) {
    throw $Message
  }
}

function Read-Text {
  param([Parameter(Mandatory = $true)][string]$Path)
  return Get-Content -Raw -Encoding UTF8 -LiteralPath $Path
}

function Assert-ValidationIssue {
  param(
    [Parameter(Mandatory = $true)]$Validation,
    [Parameter(Mandatory = $true)][string]$MessagePattern
  )
  $messages = @($Validation.issues | ForEach-Object { $_.message })
  Assert-True (($messages -match $MessagePattern).Count -gt 0) ("Expected validation issue matching '$MessagePattern'. Actual: " + ($messages -join ' | '))
}

function New-CharClass {
  param([int[]]$CodePoints)
  $escaped = foreach ($codePoint in $CodePoints) {
    [regex]::Escape(([char]$codePoint).ToString())
  }
  return '[' + ($escaped -join '') + ']'
}

$candidateSkillRoot = Join-Path $RepoRoot 'skill\agents-init'
if (Test-Path -LiteralPath $candidateSkillRoot -PathType Container) {
  $skillRoot = $candidateSkillRoot
} else {
  $skillRoot = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot '..')).Path
}
$skillFiles = Get-ChildItem -LiteralPath $skillRoot -Recurse -File -Include *.md,*.yaml,*.yml,*.ps1

$scriptParseFailures = @()
foreach ($scriptFile in (Get-ChildItem -LiteralPath (Join-Path $skillRoot 'scripts') -File -Filter *.ps1)) {
  $tokens = $null
  $parseErrors = $null
  [System.Management.Automation.Language.Parser]::ParseFile($scriptFile.FullName, [ref]$tokens, [ref]$parseErrors) | Out-Null
  if ($parseErrors.Count -gt 0) {
    $scriptParseFailures += ($scriptFile.FullName + ': ' + (($parseErrors | ForEach-Object { "$($_.Extent.StartLineNumber):$($_.Message)" }) -join ' | '))
  }
}
Assert-True ($scriptParseFailures.Count -eq 0) ("PowerShell scripts must parse cleanly: " + ($scriptParseFailures -join '; '))

$mojibakePattern = New-CharClass @(
  0x951F, 0xFFFD, 0x6D93, 0x9438, 0x93C2, 0x9359, 0x9366, 0x93C8,
  0x941E, 0x704F, 0x95C7, 0x951B, 0x93C0, 0x7035, 0x95AB, 0x6F36,
  0x59AB, 0x6D60, 0x6F7F, 0x9286, 0x942A, 0x93AC, 0x95C4
)
$badFiles = @()
foreach ($file in $skillFiles) {
  if ($file.FullName -eq $PSCommandPath -or $file.Name -eq 'test-agents-init-policy.ps1') {
    continue
  }
  if ($file.Name -eq 'validate-workflow.ps1') {
    continue
  }
  $text = Read-Text $file.FullName
  if ($text -match $mojibakePattern) {
    $badFiles += $file.FullName
  }
}
Assert-True ($badFiles.Count -eq 0) ("Skill contains likely mojibake: " + ($badFiles -join ', '))

$badModelPattern = 'claude-opus-4\.7|4\.7-thinking|--model claude-opus-|claude\.exe'
$badModelFiles = @()
foreach ($file in $skillFiles) {
  if ($file.FullName -eq $PSCommandPath -or $file.Name -eq 'test-agents-init-policy.ps1') {
    continue
  }
  if ($file.Name -eq 'validate-workflow.ps1') {
    continue
  }
  $text = Read-Text $file.FullName
  if ($text -match $badModelPattern) {
    $badModelFiles += $file.FullName
  }
}
Assert-True ($badModelFiles.Count -eq 0) ("Skill contains stale or non-portable Claude route/model text: " + ($badModelFiles -join ', '))

$doctor = Read-Text (Join-Path $skillRoot 'scripts\doctor-agents.ps1')
Assert-True ($doctor -match 'cc2' -and $doctor -match 'claude_command_routes') 'doctor-agents.ps1 must report cc2/claude command route discovery separately from Maestro.'
Assert-True ($doctor -match 'role_routes' -and $doctor -match 'explicit_claude_delegate_policy') 'doctor-agents.ps1 must report Maestro role mappings separately from explicit --to claude delegate policy.'

$multiModelReference = Read-Text (Join-Path $skillRoot 'references\multi-model-shared-context.md')
Assert-True ($multiModelReference -match 'Prefer `maestro_delegate` for Claude' -and $multiModelReference -match 'cc2` is the local Claude profile/alias reference and fallback') 'Multi-model policy must prefer Maestro delegate raw-output lifecycle and treat cc2 as profile/alias fallback, not default context dumping.'
Assert-True ($multiModelReference -match 'User-Visible Model Evidence' -and $multiModelReference -match 'raw_output_ref' -and $multiModelReference -match 'main agent''s synthesis') 'Multi-model policy must require user-visible Claude/raw model evidence, not only hidden receipt conclusions.'

$routeIntent = Read-Text (Join-Path $skillRoot 'scripts\route-intent.ps1')
Assert-True ($routeIntent -match 'prefer proven Maestro delegate' -and $routeIntent -match 'invoke-claude-review.ps1' -and $routeIntent -notmatch 'Commands @\("cc2 --safe-mode -p <compact-packet>') 'Claude intent routing must recommend the agents-init Claude invocation wrapper, not a direct cc2-only command.'
Assert-True ($routeIntent -match 'maintain-knowledge' -and $routeIntent -match 'document_lifecycle_receipt' -and $routeIntent -match '\\u6587\\u6863' -and $routeIntent -match '\\u6536\\u53e3') 'route-intent.ps1 must route Chinese/English document pile-up and changed-decision prompts to maintain-knowledge with document_lifecycle_receipt, not low-confidence clarify.'
Assert-True ($routeIntent -match 'maestro ralph skills --platform codex --json --quiet' -and $routeIntent -match 'selected project skill SKILL.md' -and $routeIntent -match 'Registry enumeration alone is insufficient' -and $routeIntent -match 'maestro grill --help') 'route-intent.ps1 must tell main agents to verify and read project-level Maestro Codex skill contracts, not stop at CLI knowledge surfaces or registry enumeration.'
Assert-True ($routeIntent -match 'main_orchestration' -and $routeIntent -match 'task_packet' -and $routeIntent -match 'branch_plan' -and $routeIntent -match 'completion_notice' -and $routeIntent -match 'data_packet' -and $routeIntent -match 'chairman_brief' -and $routeIntent -match 'parked_waiting_next_packet') 'route-intent.ps1 must recognize dynamic main/multi-worktree orchestration packet signals without treating them as old-project salvage.'
Assert-True ($routeIntent -match 'main-orchestration-intake' -and $routeIntent -match 'Do not create worktrees before recovery, goal clarification, and object/module boundary analysis') 'route-intent.ps1 must route main orchestration to an intake gate and forbid blind worktree creation.'
Assert-True ($routeIntent -match 'evidence_exhaustion' -and $routeIntent -match 'negative_searches' -and $routeIntent -match 'not_read_open_gap' -and $routeIntent -match 'rg alone is not evidence exhaustion') 'route-intent.ps1 must detect context compression/evidence exhaustion as a low-frequency guardrail with explicit proof boundaries.'

$routeIntentScript = Join-Path $skillRoot 'scripts\route-intent.ps1'
$compressedRgJson = & powershell -NoProfile -ExecutionPolicy Bypass -File $routeIntentScript -ProjectPath $RepoRoot -Prompt 'worker was compressed and says rg found no evidence' -Json
Assert-True ($LASTEXITCODE -eq 0) "route-intent compressed/rg pressure sample must run. Output: $compressedRgJson"
$compressedRgRoute = $compressedRgJson | ConvertFrom-Json
Assert-True ($compressedRgRoute.result.route -eq 'evidence-exhaustion-guardrail') 'route-intent must prioritize evidence-exhaustion when worker/compression signals collide with rg/no-evidence absence claims.'

$mainRegistrationPolicyTerms = @('pre_registration_packet', 'official_registration_packet', 'active_main is unknown until the real thread id returns', 'project-local rules are carried in task packets or project AGENTS.md')
foreach ($term in $mainRegistrationPolicyTerms) {
  Assert-True ($routeIntent -match [regex]::Escape($term) -or (Read-Text (Join-Path $skillRoot 'references\codex-thread-protocol.md')) -match [regex]::Escape($term) -or (Read-Text (Join-Path $skillRoot 'references\main-worktree-orchestration.md')) -match [regex]::Escape($term)) "agents-init must document main-thread pre-registration and project-rule layering term: $term"
}

$codexThreadProtocol = Read-Text (Join-Path $skillRoot 'references\codex-thread-protocol.md')
Assert-True ($codexThreadProtocol -match 'Do not fixed-interval poll' -and $codexThreadProtocol -match 'natural completion' -and $codexThreadProtocol -match 'user asks for status') 'Codex thread protocol must forbid fixed-interval worker polling and prefer natural completion/status-on-demand.'
Assert-True ($codexThreadProtocol -match 'ingest-receipt\.ps1 -Apply -Decision accepted\|rejected' -and $codexThreadProtocol -match 'verification\.yaml' -and $codexThreadProtocol -match 'thread_registry\.yaml' -and $codexThreadProtocol -match 'does not replace UI/sample/business') 'Codex thread protocol must document explicit receipt apply behavior and its human-gate boundary.'
Assert-True ($codexThreadProtocol -match 'pre_registration_packet' -and $codexThreadProtocol -match 'official_registration_packet' -and $codexThreadProtocol -match 'active_main is unknown until the real thread id returns') 'Codex thread protocol must document pre-registration for newly created main/branch sessions before the real thread id is known.'

$multiCodexSessionDoc = Read-Text (Join-Path $skillRoot 'assets\project-template\docs\dev-os\multi-codex-session-mode.md')
Assert-True ($multiCodexSessionDoc -match 'No fixed-interval recall' -and $multiCodexSessionDoc -match 'wait for the worker receipt') 'Project docs must tell main agents not to create 30-second recall loops for worker threads.'
Assert-True ($multiCodexSessionDoc -match 'ingest-receipt\.ps1 -Apply -Decision accepted\|rejected' -and $multiCodexSessionDoc -match 'init-agents\.ps1.*-ApplyReceipt' -and $multiCodexSessionDoc -match 'does not replace artifact inspection or human-gated acceptance') 'Project multi-session docs must show the receipt apply command and boundary.'

$skillEntry = Read-Text (Join-Path $skillRoot 'SKILL.md')
Assert-True ($skillEntry -match 'no fixed-interval recall' -and $skillEntry -match 'natural completion' -and $skillEntry -match 'wait for the receipt') 'SKILL.md top-level worker guidance must forbid fixed-interval recall loops and prefer natural completion.'
Assert-True ($skillEntry -match 'ingest-receipt\.ps1.*-Apply.*-Decision accepted\|rejected' -and $skillEntry -match 'ApplyReceipt' -and $skillEntry -match 'main-agent receipt decision') 'SKILL.md must expose the receipt apply path without implying shape-check equals acceptance.'
Assert-True ($skillEntry -match 'Maestro skills are not Claude delegate' -and $skillEntry -match 'spec/knowhow/search/KG/wiki/domain/workspace/msg/overlay' -and $skillEntry -match 'invoke-maestro-skill.ps1') 'SKILL.md must make non-Claude Maestro skills a first-class orchestration path, not hide behind Claude delegate.'
Assert-True ($skillEntry -match 'Project-level Maestro Codex skills' -and $skillEntry -match 'maestro ralph skills --platform codex --json' -and $skillEntry -match 'read the selected project skill''s SKILL.md' -and $skillEntry -match 'Registry discovery alone is not execution') 'SKILL.md must distinguish Maestro CLI knowledge surfaces from project-level Maestro Codex skill invocation and forbid treating registry discovery alone as execution.'
Assert-True ($skillEntry -match 'Dynamic Main / Multi-Worktree Orchestration' -and $skillEntry -match 'agents-init main' -and $skillEntry -match 'optional shortcut' -and $skillEntry -match 'state-driven, not keyword-driven') 'SKILL.md must describe dynamic main orchestration while keeping agents-init main optional and state-driven.'
Assert-True ($skillEntry -match 'task_packet' -and $skillEntry -match 'branch_plan' -and $skillEntry -match 'completion_notice' -and $skillEntry -match 'data_packet' -and $skillEntry -match 'chairman_brief' -and $skillEntry -match 'parked_waiting_next_packet') 'SKILL.md must expose the multi-worktree orchestration packet lifecycle.'
Assert-True ($skillEntry -match 'Context Hygiene And Evidence Exhaustion' -and $skillEntry -match 'low-frequency high-risk guardrail' -and $skillEntry -match 'rg alone is not evidence exhaustion') 'SKILL.md must keep evidence exhaustion as a bounded guardrail and forbid treating rg-only searches as full proof.'
Assert-True ($skillEntry -match 'project-local rules' -and $skillEntry -match 'generic agents-init rules' -and $skillEntry -match 'pre_registration_packet') 'SKILL.md must separate project-local orchestration rules from generic agents-init rules and document pre-registration for new main threads.'

$invokeMaestroSkill = Join-Path $skillRoot 'scripts\invoke-maestro-skill.ps1'
Assert-True (Test-Path -LiteralPath $invokeMaestroSkill -PathType Leaf) 'agents-init must include invoke-maestro-skill.ps1 for first-class non-Claude Maestro skills.'
$invokeMaestroSkillText = Read-Text $invokeMaestroSkill
foreach ($surface in @("'diagnose'", "'search'", "'spec'", "'knowhow'", "'wiki'", "'kg'", "'domain'", "'workspace'", "'msg'", "'overlay'", "'delegate-config'")) {
  Assert-True ($invokeMaestroSkillText -match [regex]::Escape($surface)) "invoke-maestro-skill.ps1 must expose Maestro surface $surface."
}
Assert-True ($invokeMaestroSkillText -match 'maestro search' -and $invokeMaestroSkillText -match 'maestro spec' -and $invokeMaestroSkillText -match 'maestro knowhow' -and $invokeMaestroSkillText -match 'maestro kg') 'invoke-maestro-skill.ps1 must expose Maestro search/spec/knowhow/kg and related skill surfaces.'
Assert-True ($invokeMaestroSkillText -match 'raw_output_non_empty' -and $invokeMaestroSkillText -match 'does_not_prove' -and $invokeMaestroSkillText -match 'Claude delegate') 'invoke-maestro-skill.ps1 must return receipt-shaped proof boundaries and explicitly avoid treating Maestro skills as Claude delegate proof.'

$maestroRoutingReference = Read-Text (Join-Path $skillRoot 'references\maestro-routing.md')
Assert-True ($maestroRoutingReference -match 'Project-Level Maestro Codex Skills' -and $maestroRoutingReference -match 'CLI knowledge surfaces' -and $maestroRoutingReference -match 'Codex skill invocation surfaces' -and $maestroRoutingReference -match 'maestro grill` is not a CLI proof') 'Maestro routing reference must explain the difference between CLI knowledge commands and Codex project skill invocation.'
Assert-True ($maestroRoutingReference -match 'Minimum accepted live smoke' -and $maestroRoutingReference -match 'read selected project skill `SKILL.md`' -and $maestroRoutingReference -match 'receipt with proves and does_not_prove') 'Maestro routing reference must require a live-smoke standard stronger than registry enumeration.'

$invokeClaude = Join-Path $skillRoot 'scripts\invoke-claude-review.ps1'
Assert-True (Test-Path -LiteralPath $invokeClaude -PathType Leaf) 'agents-init must include invoke-claude-review.ps1 so other sessions can actually call Claude and read raw output.'
$invokeClaudeText = Read-Text $invokeClaude
Assert-True ($invokeClaudeText -match 'maestro delegate output' -and $invokeClaudeText -match 'raw_output_non_empty' -and $invokeClaudeText -match 'exec_id') 'invoke-claude-review.ps1 must call Maestro delegate, read delegate output, and report exec_id/raw_output_non_empty.'

$validateWorkflowText = Read-Text (Join-Path $skillRoot 'scripts\validate-workflow.ps1')
$templateFiles = Get-ChildItem -LiteralPath (Join-Path $skillRoot 'assets\project-template\.workflow\templates') -File | Sort-Object Name
$missingTemplateValidation = @()
foreach ($templateFile in $templateFiles) {
  $requiredPath = '.workflow/templates/' + $templateFile.Name
  if ($validateWorkflowText -notmatch [regex]::Escape($requiredPath)) {
    $missingTemplateValidation += $requiredPath
  }
}
Assert-True ($missingTemplateValidation.Count -eq 0) ("validate-workflow.ps1 requiredFiles must cover every project template file. Missing: " + ($missingTemplateValidation -join ', '))

$authorityIndexTemplatePath = Join-Path $skillRoot 'assets\project-template\.workflow\authority_index.yaml'
Assert-True (Test-Path -LiteralPath $authorityIndexTemplatePath -PathType Leaf) 'agents-init must include authority_index.yaml as the canonical active/superseded/promoted artifact ledger.'
$authorityIndexTemplate = Read-Text $authorityIndexTemplatePath
Assert-True ($authorityIndexTemplate -match 'current_authority:' -and $authorityIndexTemplate -match 'active_evidence:' -and $authorityIndexTemplate -match 'superseded:' -and $authorityIndexTemplate -match 'promoted:' -and $authorityIndexTemplate -match 'archived:') 'authority_index.yaml must classify current authority, active evidence, superseded artifacts, promoted knowledge, and archives.'

$workflowCloseoutTemplatePath = Join-Path $skillRoot 'assets\project-template\.workflow\templates\workflow_closeout_receipt.yaml'
Assert-True (Test-Path -LiteralPath $workflowCloseoutTemplatePath -PathType Leaf) 'agents-init must include workflow_closeout_receipt.yaml for route/gate/direction/handoff/promotion closeout transactions.'
$workflowCloseoutTemplate = Read-Text $workflowCloseoutTemplatePath
foreach ($field in @('reason:', 'active_head_before:', 'active_head_after:', 'updated_heads:', 'authority_index_updates:', 'maestro_promotions:', 'session_recovery_update:', 'validation_status:', 'proves:', 'does_not_prove:')) {
  Assert-True ($workflowCloseoutTemplate -match [regex]::Escape($field)) "workflow_closeout_receipt.yaml must include $field."
}

Assert-True ($validateWorkflowText -match '\.workflow/authority_index\.yaml' -and $validateWorkflowText -match '\.workflow/templates/workflow_closeout_receipt\.yaml') 'validate-workflow.ps1 must require authority_index.yaml and workflow_closeout_receipt.yaml.'
Assert-True ($validateWorkflowText -match 'authority_index\.yaml should include current_authority' -and $validateWorkflowText -match 'workflow_closeout_receipt\.yaml must include') 'validate-workflow.ps1 must validate authority index and closeout receipt contract fields.'
Assert-True ($validateWorkflowText -match 'session-recovery brief appears stale' -and $validateWorkflowText -match 'task.yaml active_task appears older than latest verification evidence') 'validate-workflow.ps1 must warn about stale recovery briefs and stale active tasks.'
Assert-True ($validateWorkflowText -match 'task_packet\.yaml' -and $validateWorkflowText -match 'branch_plan\.yaml' -and $validateWorkflowText -match 'branch_completion_notice\.yaml' -and $validateWorkflowText -match 'cross_project_data_packet\.yaml' -and $validateWorkflowText -match 'chairman_brief\.yaml') 'validate-workflow.ps1 must require the dynamic main orchestration templates.'
Assert-True ($validateWorkflowText -match 'parked_waiting_next_packet' -and $validateWorkflowText -match 'completion_notice is not acceptance' -and $validateWorkflowText -match 'chairman_brief is required before claiming orchestrator synthesis') 'validate-workflow.ps1 must warn about false completion in parked branch orchestration states.'
Assert-True ($validateWorkflowText -match 'evidence_exhaustion_check\.yaml' -and $validateWorkflowText -match 'negative_searches' -and $validateWorkflowText -match 'not_read_open_gap') 'validate-workflow.ps1 must validate the evidence exhaustion guardrail fields.'

$closeoutWorkflowScript = Join-Path $skillRoot 'scripts\closeout-workflow.ps1'
Assert-True (Test-Path -LiteralPath $closeoutWorkflowScript -PathType Leaf) 'agents-init must include closeout-workflow.ps1 to record lifecycle closeout transactions.'
$closeoutWorkflowText = Read-Text $closeoutWorkflowScript
Assert-True ($closeoutWorkflowText -match 'workflow_closeout_receipt' -and $closeoutWorkflowText -match 'authority_index' -and $closeoutWorkflowText -match 'verification\.yaml' -and $closeoutWorkflowText -match 'session-recovery') 'closeout-workflow.ps1 must write a closeout receipt, update authority_index/verification, and refresh session recovery.'
Assert-True ($closeoutWorkflowText -match 'route_change' -and $closeoutWorkflowText -match 'direction_correction' -and $closeoutWorkflowText -match 'promotion' -and $closeoutWorkflowText -match 'archive_cleanup') 'closeout-workflow.ps1 must support route, correction, promotion, and archive cleanup reasons.'
Assert-True ($closeoutWorkflowText -match 'does_not_prove' -and $closeoutWorkflowText -match 'not product acceptance') 'closeout-workflow.ps1 must preserve proof boundaries and not claim product acceptance.'

$initAgentsText = Read-Text (Join-Path $skillRoot 'scripts\init-agents.ps1')
Assert-True ($initAgentsText -match "'closeout-workflow'" -and $initAgentsText -match 'CloseoutReason' -and $initAgentsText -match 'closeout-workflow\.ps1') 'init-agents.ps1 must expose closeout-workflow mode through the wrapper.'

$modelPolicyTemplate = Read-Text (Join-Path $skillRoot 'assets\project-template\.workflow\model_policy.yaml')
Assert-True ($modelPolicyTemplate -match 'preferred_route: maestro_delegate_when_raw_output_proven' -and $modelPolicyTemplate -match 'cc2_profile_reference') 'model_policy template must encode Maestro delegate as preferred proven lifecycle and cc2 as a local profile reference/fallback.'

$caseStudy = Read-Text (Join-Path $skillRoot 'references\case-studies\ozon-canvas.md')
Assert-True ($caseStudy -match '/image mainline integration vs /canvas/ozon-suite sidecar drift') 'Ozon/Canvas case study must name the required first diagnosis exactly.'

$painRules = Read-Text (Join-Path $skillRoot 'references\pain-point-rules.md')
Assert-True ($painRules -match 'Product-System Fit Gate' -and $painRules -match 'surface symptom, not the decision' -and $painRules -match 'new projects') 'Pain point rules must define a general Product-System Fit Gate where surface words are weak signals, not routing truth.'
Assert-True ($painRules -match 'Do not reduce "not a standalone page" to "move it into a panel"' -and $painRules -match 'product structure, workflow ownership, interaction grammar') 'Pain point rules must forbid shallow fixes that only move the surface without product-system analysis.'
Assert-True ($painRules -match 'Do not confuse placement with integration' -and $painRules -match 'object ownership' -and $painRules -match 'workflow ownership' -and $painRules -match 'reused capabilities') 'Pain point rules must define integration as ownership, reuse, data/state lifecycle, interaction grammar, and acceptance surface rather than placement.'

$mainOrchestration = Read-Text (Join-Path $skillRoot 'references\main-agent-orchestration.md')
Assert-True ($mainOrchestration -match 'product_system_fit_gate' -and $mainOrchestration -match 'information architecture' -and $mainOrchestration -match 'interaction grammar') 'Main-agent orchestration must require product_system_fit_gate fields for UI/workflow/product-shape tasks.'
Assert-True ($mainOrchestration -match 'Correct Direction Is Not Enough' -and $mainOrchestration -match 'evidence_bound_product_fit' -and $mainOrchestration -match 'native_interaction_grammar' -and $mainOrchestration -match 'capability_reuse_plan' -and $mainOrchestration -match 'first_visible_slice_acceptance') 'Main-agent orchestration must treat correct product direction as insufficient without evidence-bound product fit, native interaction grammar, capability reuse, and first visible slice acceptance.'
Assert-True ($mainOrchestration -match 'User-Visible Product-System Receipt' -and $mainOrchestration -match 'Recovered anchors:' -and $mainOrchestration -match 'Product-System Fit:' -and $mainOrchestration -match 'summary_only_failure') 'Main-agent orchestration must require a user-visible Product-System receipt for old-page/new-page/workbench confusion, not just prose.'
Assert-True ($mainOrchestration -match 'For integration claims, use Product-System Fit as an Integration Fit Gate' -and $mainOrchestration -match 'global_nav' -and $mainOrchestration -match 'first_level_workspace' -and $mainOrchestration -match 'editor_internal_panel') 'Main-agent orchestration must distinguish integration surface levels without adding a separate top-level gate.'

$mainWorktreeOrchestrationPath = Join-Path $skillRoot 'references\main-worktree-orchestration.md'
Assert-True (Test-Path -LiteralPath $mainWorktreeOrchestrationPath -PathType Leaf) 'agents-init must include main-worktree-orchestration.md for dynamic main/multi-worktree control-plane rules.'
$mainWorktreeOrchestration = Read-Text $mainWorktreeOrchestrationPath
Assert-True ($mainWorktreeOrchestration -match 'agents-init main is optional' -and $mainWorktreeOrchestration -match 'default entry remains agents-init' -and $mainWorktreeOrchestration -match 'Do not create worktrees blindly') 'main-worktree-orchestration reference must preserve user habit compatibility and prevent blind worktree creation.'
Assert-True ($mainWorktreeOrchestration -match 'task_packet -> branch_plan -> completion_notice -> data_packet -> chairman_brief -> parked_waiting_next_packet' -and $mainWorktreeOrchestration -match 'Ozon is a case study, not a rule template') 'main-worktree-orchestration reference must define the generic packet lifecycle and avoid hardcoding Ozon lanes.'

$contextHygieneReferencePath = Join-Path $skillRoot 'references\context-hygiene-and-evidence-exhaustion.md'
Assert-True (Test-Path -LiteralPath $contextHygieneReferencePath -PathType Leaf) 'agents-init must include context-hygiene-and-evidence-exhaustion.md for branch compression and evidence-heavy work.'
$contextHygieneReference = Read-Text $contextHygieneReferencePath
Assert-True ($contextHygieneReference -match 'low-frequency high-risk guardrail' -and $contextHygieneReference -match 'negative_searches' -and $contextHygieneReference -match 'not_read_open_gap' -and $contextHygieneReference -match 'rg alone is not evidence exhaustion') 'context hygiene reference must define evidence exhaustion as a bounded guardrail with negative search and not-read gap tracking.'

$ozonCaseStudy = Read-Text (Join-Path $skillRoot 'references\case-studies\ozon-canvas.md')
Assert-True ($ozonCaseStudy -match 'Screenshot Failure Update' -and $ozonCaseStudy -match 'directionally improved clarification' -and $ozonCaseStudy -match 'compact Product-System receipt') 'Ozon/Canvas case study must mark the latest screenshot-style answer as improved but not a full pass without a compact Product-System receipt.'

$orchTemplate = Read-Text (Join-Path $skillRoot 'assets\project-template\.workflow\templates\orchestration_decision.yaml')
Assert-True ($orchTemplate -match 'product_system_fit_gate:' -and $orchTemplate -match 'surface_symptoms:' -and $orchTemplate -match 'system_role_hypotheses:' -and $orchTemplate -match 'weak_signal_only: true') 'Orchestration decision template must include product_system_fit_gate with weak-signal surface symptoms.'
Assert-True ($orchTemplate -match 'evidence_bound_product_fit:' -and $orchTemplate -match 'native_interaction_grammar:' -and $orchTemplate -match 'capability_reuse_plan:' -and $orchTemplate -match 'first_visible_slice_acceptance:' -and $orchTemplate -match 'summary_only_failure: true') 'Orchestration decision template must include evidence-bound product fit fields and mark summary-only direction fixes as failure.'
Assert-True ($orchTemplate -match 'integration_fit:' -and $orchTemplate -match 'target_surface_level:' -and $orchTemplate -match 'object_owner:' -and $orchTemplate -match 'workflow_owner:' -and $orchTemplate -match 'anti_misclassification_check:') 'Orchestration decision template must include integration_fit fields for surface level, ownership, reuse, and anti-misclassification checks.'

$threadRegistryTemplate = Read-Text (Join-Path $skillRoot 'assets\project-template\.workflow\thread_registry.yaml')
Assert-True ($threadRegistryTemplate -match 'no_output' -and $threadRegistryTemplate -match 'interrupted' -and $threadRegistryTemplate -match 'restarted' -and $threadRegistryTemplate -match 'close_reason') 'thread_registry template must model no_output/interrupted/restarted worker lifecycle states with close_reason.'
Assert-True ($threadRegistryTemplate -match 'branch_actors:' -and $threadRegistryTemplate -match 'parked_waiting_next_packet' -and $threadRegistryTemplate -match 'task_packet_path:' -and $threadRegistryTemplate -match 'branch_plan_path:' -and $threadRegistryTemplate -match 'data_packet_paths:') 'thread_registry template must model branch actors, packet paths, and parked waiting state for dynamic main orchestration.'
Assert-True ($threadRegistryTemplate -match 'pre_registration_packet:' -and $threadRegistryTemplate -match 'official_registration_packet:' -and $threadRegistryTemplate -match 'identity_status: pending_real_thread_id') 'thread_registry template must model pre-registration and official registration for new main/branch thread identity.'

foreach ($templateName in @('thread_pre_registration_packet.yaml', 'thread_official_registration_packet.yaml', 'task_packet.yaml', 'branch_plan.yaml', 'branch_completion_notice.yaml', 'cross_project_data_packet.yaml', 'chairman_brief.yaml', 'evidence_exhaustion_check.yaml', 'evidence_digest.yaml')) {
  Assert-True (Test-Path -LiteralPath (Join-Path $skillRoot "assets\project-template\.workflow\templates\$templateName") -PathType Leaf) "agents-init must include $templateName for dynamic branch orchestration and context hygiene."
}
$preRegistrationTemplate = Read-Text (Join-Path $skillRoot 'assets\project-template\.workflow\templates\thread_pre_registration_packet.yaml')
Assert-True ($preRegistrationTemplate -match 'active_main_is_unknown_until_real_thread_id_returns: true' -and $preRegistrationTemplate -match 'temporary_identity: pending_real_thread_id' -and $preRegistrationTemplate -match 'project_local_rules_are_not_global_skill_rules: true') 'thread_pre_registration_packet.yaml must encode pending thread identity and project-rule layering.'
$officialRegistrationTemplate = Read-Text (Join-Path $skillRoot 'assets\project-template\.workflow\templates\thread_official_registration_packet.yaml')
Assert-True ($officialRegistrationTemplate -match 'real_thread_id:' -and $officialRegistrationTemplate -match 'pre_registration_ref:' -and $officialRegistrationTemplate -match 'Registration does not prove task completion') 'thread_official_registration_packet.yaml must encode concrete thread id registration and proof boundaries.'
$taskPacketTemplate = Read-Text (Join-Path $skillRoot 'assets\project-template\.workflow\templates\task_packet.yaml')
Assert-True ($taskPacketTemplate -match 'orchestrator_authorization:' -and $taskPacketTemplate -match 'goal_slice:' -and $taskPacketTemplate -match 'must_not_decide:' -and $taskPacketTemplate -match 'expected_return_packet:') 'task_packet.yaml must encode main-agent authorization, goal slice, forbidden decisions, and expected return packet.'
$branchPlanTemplate = Read-Text (Join-Path $skillRoot 'assets\project-template\.workflow\templates\branch_plan.yaml')
Assert-True ($branchPlanTemplate -match 'worktree:' -and $branchPlanTemplate -match 'module_boundary:' -and $branchPlanTemplate -match 'conflict_set:' -and $branchPlanTemplate -match 'verification_surface:') 'branch_plan.yaml must encode worktree, module boundary, conflicts, and verification surface.'
$completionNoticeTemplate = Read-Text (Join-Path $skillRoot 'assets\project-template\.workflow\templates\branch_completion_notice.yaml')
Assert-True ($completionNoticeTemplate -match 'completion_notice_is_not_acceptance' -and $completionNoticeTemplate -match 'parked_waiting_next_packet') 'branch_completion_notice.yaml must state that completion notice is not acceptance and normally parks the branch.'
$dataPacketTemplate = Read-Text (Join-Path $skillRoot 'assets\project-template\.workflow\templates\cross_project_data_packet.yaml')
Assert-True ($dataPacketTemplate -match 'payload_index:' -and $dataPacketTemplate -match 'proves:' -and $dataPacketTemplate -match 'does_not_prove:' -and $dataPacketTemplate -match 'orchestrator_decision_required: true') 'cross_project_data_packet.yaml must preserve payload index and proof boundaries and require orchestrator decision.'
$chairmanBriefTemplate = Read-Text (Join-Path $skillRoot 'assets\project-template\.workflow\templates\chairman_brief.yaml')
Assert-True ($chairmanBriefTemplate -match 'main_agent_synthesis:' -and $chairmanBriefTemplate -match 'accepted_findings:' -and $chairmanBriefTemplate -match 'rejected_findings:' -and $chairmanBriefTemplate -match 'upstream_questions:') 'chairman_brief.yaml must encode main-agent synthesis and 1-3 upstream questions for the user.'
$evidenceExhaustionTemplate = Read-Text (Join-Path $skillRoot 'assets\project-template\.workflow\templates\evidence_exhaustion_check.yaml')
Assert-True ($evidenceExhaustionTemplate -match 'negative_searches:' -and $evidenceExhaustionTemplate -match 'not_read_open_gap:' -and $evidenceExhaustionTemplate -match 'methods:' -and $evidenceExhaustionTemplate -match 'rg_alone_is_not_exhaustion: true') 'evidence_exhaustion_check.yaml must require methods, negative searches, not-read gaps, and forbid rg-only exhaustion claims.'

$designDebateTemplate = Read-Text (Join-Path $skillRoot 'assets\project-template\.workflow\templates\design_debate_receipt.yaml')
Assert-True ($designDebateTemplate -match 'participants:' -and $designDebateTemplate -match 'accepted_objections:' -and $designDebateTemplate -match 'rejected_objections:' -and $designDebateTemplate -match 'main_agent_synthesis:' -and $designDebateTemplate -match 'does_not_prove:') 'design_debate_receipt template must expose participants, objections, main-agent synthesis, and does_not_prove.'

$documentLifecycleTemplatePath = Join-Path $skillRoot 'assets\project-template\.workflow\templates\document_lifecycle_receipt.yaml'
Assert-True (Test-Path -LiteralPath $documentLifecycleTemplatePath -PathType Leaf) 'agents-init must include document_lifecycle_receipt.yaml for unfinished docs, changed decisions, and scattered receipts.'
$documentLifecycleTemplate = Read-Text $documentLifecycleTemplatePath
Assert-True ($documentLifecycleTemplate -match 'source_artifact:' -and $documentLifecycleTemplate -match 'current_status: active \| unresolved \| superseded \| archived \| promoted \| rejected' -and $documentLifecycleTemplate -match 'decision_state: proposed \| changed \| accepted \| blocked \| stale') 'document_lifecycle_receipt must classify artifact status and decision state.'
Assert-True ($documentLifecycleTemplate -match 'active_claims:' -and $documentLifecycleTemplate -match 'unresolved_questions:' -and $documentLifecycleTemplate -match 'superseded_by:' -and $documentLifecycleTemplate -match 'promote_to:' -and $documentLifecycleTemplate -match 'restore_or_trace_ref:' -and $documentLifecycleTemplate -match 'does_not_prove:') 'document_lifecycle_receipt must expose active claims, unresolved questions, supersession, promotion target, trace/restore reference, and proof boundaries.'

$pressureTests = Read-Text (Join-Path $skillRoot 'scripts\pressure-test-agents.ps1')
Assert-True ($pressureTests -match 'PT-PRODUCT-SYSTEM-002' -and $pressureTests -match 'direction is right but still not enough' -and $pressureTests -match 'must cite original product anchors') 'Pressure tests must include the sample failure where the answer states the right direction but still lacks project evidence and design-gate proof.'
Assert-True ($pressureTests -match 'PT-PRODUCT-SYSTEM-003' -and $pressureTests -match 'user-visible Product-System receipt' -and $pressureTests -match 'summary_only_failure') 'Pressure tests must include the sample screenshot failure where old-page/new-page confusion receives prose but no visible PFIT receipt.'
Assert-True ($pressureTests -match 'PT-INTEGRATION-FIT-001' -and $pressureTests -match 'global navigation item' -and $pressureTests -match 'Do not treat access or placement as integration') 'Pressure tests must catch the failure where global navigation or workbench access is mistaken for editor/workflow integration.'
Assert-True ($pressureTests -match 'PT-INTEGRATION-FIT-002' -and $pressureTests -match 'reuse the original editor nodes' -and $pressureTests -match 'anti-sidecar risks') 'Pressure tests must catch the failure where a separate workbench continues without an editor-native handoff and object/data contract.'
Assert-True ($pressureTests -match 'PT-INTEGRATION-FIT-003' -and $pressureTests -match 'separates /canvas/ozon-suite as prototype workbench' -and $pressureTests -match 'object_owner' -and $pressureTests -match 'workflow_owner' -and $pressureTests -match 'topbar \+ right panel \+ node metadata') 'Pressure tests must catch the partial-pass trap where three-surface separation and a plausible editor-native slice still lack ownership/contracts and PFIT proof.'
Assert-True ($pressureTests -match 'PT-KNOWLEDGE-LIFECYCLE-001' -and $pressureTests -match 'unfinished docs and decisions changed while talking' -and $pressureTests -match 'document_lifecycle_receipt') 'Pressure tests must catch the document-fragmentation failure where the agent appends another summary instead of classifying active/unresolved/superseded/archive/promote.'
Assert-True ($pressureTests -match 'PT-MAESTRO-SKILL-ORCH-001' -and $pressureTests -match 'Maestro Grill/knowledge/KG' -and $pressureTests -match 'read the selected project skill SKILL.md' -and $pressureTests -match 'Registry enumeration alone is insufficient') 'Pressure tests must catch the failure where agents-init only enumerates Maestro skills but does not invoke/read the project-level skill contract.'

$workflowSchema = Read-Text (Join-Path $skillRoot 'references\workflow-schema.md')
Assert-True ($workflowSchema -match 'Document Triage Receipt' -and $workflowSchema -match 'active, unresolved, superseded, archived, promoted, or rejected' -and $workflowSchema -match 'Do not append another summary') 'Workflow schema must require document triage receipt behavior for unfinished docs and changed decisions.'

$usagePlaybook = Read-Text (Join-Path $skillRoot 'references\usage-playbook.md')
Assert-True ($usagePlaybook -match 'Document Triage Receipt' -and $usagePlaybook -match 'decisions changed mid-conversation' -and $usagePlaybook -match 'first classify artifacts') 'Usage playbook must tell main agents to classify fragmented docs before proposing more work.'

Assert-True ($orchTemplate -match 'documents_to_triage:' -and $orchTemplate -match 'unresolved_docs_to_open_threads:' -and $orchTemplate -match 'documents_to_supersede:' -and $orchTemplate -match 'receipts_to_archive:') 'Orchestration decision knowledge_lifecycle must include explicit document triage, unresolved-doc, supersession, and receipt archive actions.'

$installScript = Read-Text (Join-Path $RepoRoot 'scripts\install-local.ps1')
Assert-True ($installScript -match 'skill-backups' -and $installScript -match 'agents-init\.backup\.\*') 'install-local.ps1 must store or quarantine backups outside the skills discovery root.'
Assert-True ($installScript -notmatch 'Join-Path\s+\$targetRoot\s+"agents-init\.backup\.\$stamp"') 'install-local.ps1 must not create discoverable agents-init.backup.* skill directories under the skills root.'

$initScript = Join-Path $skillRoot 'scripts\init-agents.ps1'
$claudeWrapper = Read-Text (Join-Path $skillRoot 'scripts\invoke-claude-review.ps1')
Assert-True ($claudeWrapper -match '\$delegateMode\s*=\s*switch' -and $claudeWrapper -match "'review', 'plan', 'brainstorm'" -and $claudeWrapper -match "default \{ 'analysis' \}") 'invoke-claude-review.ps1 must map review/plan/brainstorm to Maestro analysis mode instead of passing invalid Maestro modes.'

$upgradeTestRoot = Join-Path ([System.IO.Path]::GetTempPath()) ("agents-init-upgrade-test-" + [guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory -Force -Path (Join-Path $upgradeTestRoot '.workflow\templates') | Out-Null
New-Item -ItemType Directory -Force -Path (Join-Path $upgradeTestRoot 'docs\dev-os') | Out-Null
try {
  $badChar = [char]0x951F
  @"
protocol_version: 1
purpose: "legacy project control plane"
main_agent:
  active_thread_id: "thread-keep-me"
  source: user_provided
  status: active
interaction_menu:
  recover:
    trigger:
      - "$badChar old mojibake"
"@ | Set-Content -LiteralPath (Join-Path $upgradeTestRoot '.workflow\agents-init.yaml') -Encoding UTF8

  @'
id: ""
user_words: ""
recovered_state:
  goal: ""
recommended_route: direct | clarify | worker | maestro_delegate
maestro_use:
  needed: false
  route: none | delegate | ralph | spec | knowhow
codex_app_workers:
  needed: false
  worker_count: 0
  tasks:
    - task_id: ""
      bounded_question: ""
human_gates:
  required:
    - ""
'@ | Set-Content -LiteralPath (Join-Path $upgradeTestRoot '.workflow\templates\orchestration_decision.yaml') -Encoding UTF8

  @'
# Old Orchestration Loop

stale docs
'@ | Set-Content -LiteralPath (Join-Path $upgradeTestRoot 'docs\dev-os\orchestration-loop.md') -Encoding UTF8

  & powershell -NoProfile -ExecutionPolicy Bypass -File $initScript -ProjectPath $upgradeTestRoot -Mode upgrade | Out-Null
  if ($LASTEXITCODE -ne 0) {
    throw "Upgrade smoke command failed with exit code $LASTEXITCODE"
  }

  $upgradedAgents = Read-Text (Join-Path $upgradeTestRoot '.workflow\agents-init.yaml')
  $upgradedDecision = Read-Text (Join-Path $upgradeTestRoot '.workflow\templates\orchestration_decision.yaml')
  $upgradedDocs = Read-Text (Join-Path $upgradeTestRoot 'docs\dev-os\orchestration-loop.md')
  $upgradedDebateReceiptPath = Join-Path $upgradeTestRoot '.workflow\templates\design_debate_receipt.yaml'
  $missingUpgradeTemplates = @()
  foreach ($templateFile in $templateFiles) {
    $upgradedTemplatePath = Join-Path $upgradeTestRoot ('.workflow\templates\' + $templateFile.Name)
    if (-not (Test-Path -LiteralPath $upgradedTemplatePath -PathType Leaf)) {
      $missingUpgradeTemplates += $templateFile.Name
    }
  }

  Assert-True ($upgradedAgents -match 'protocol_version:\s*2') 'Upgrade must refresh .workflow/agents-init.yaml to protocol_version 2.'
  Assert-True ($upgradedAgents -match 'active_thread_id:\s*"thread-keep-me"') 'Upgrade must preserve the project active_thread_id while refreshing managed agents-init.yaml content.'
  Assert-True ($upgradedAgents.IndexOf($badChar) -lt 0) 'Upgrade must replace mojibake in managed agents-init.yaml content.'
  Assert-True ($upgradedDecision -match 'route:\s*none \| delegate \| ralph \| spec \| knowhow \| search \| kg \| msg \| overlay') 'Upgrade must refresh stale orchestration decision template route options.'
  Assert-True ($upgradedDecision -match 'lifecycle:\s*one_shot \| continuous') 'Upgrade must refresh stale Codex App worker lifecycle fields.'
  Assert-True (Test-Path -LiteralPath $upgradedDebateReceiptPath -PathType Leaf) 'Upgrade must add missing design_debate_receipt.yaml to existing project workflows.'
  Assert-True ($missingUpgradeTemplates.Count -eq 0) ("Upgrade must add every managed workflow template. Missing: " + ($missingUpgradeTemplates -join ', '))
  Assert-True ($upgradedDocs -match 'Main Agent Orchestration Loop' -and $upgradedDocs -match 'retrieve anchors before asking questions') 'Upgrade must refresh managed docs/dev-os files, not leave stale old docs.'
} finally {
  if (Test-Path -LiteralPath $upgradeTestRoot -PathType Container) {
    $resolvedTmp = (Resolve-Path -LiteralPath $upgradeTestRoot).Path
    $tmpBase = [System.IO.Path]::GetTempPath()
    if ($resolvedTmp.StartsWith($tmpBase, [System.StringComparison]::OrdinalIgnoreCase)) {
      Remove-Item -LiteralPath $resolvedTmp -Recurse -Force
    }
  }
}

$validateScript = Join-Path $skillRoot 'scripts\validate-workflow.ps1'
$templateRoot = Join-Path $skillRoot 'assets\project-template'
$healthWarningRoot = Join-Path ([System.IO.Path]::GetTempPath()) ("agents-init-health-warning-test-" + [guid]::NewGuid().ToString('N'))
try {
  Copy-Item -LiteralPath $templateRoot -Destination $healthWarningRoot -Recurse

  $verificationPath = Join-Path $healthWarningRoot '.workflow\verification.yaml'
  $largeLines = @('verification_log:')
  for ($i = 1; $i -le 210; $i++) {
    $largeLines += "- id: noisy_$i"
    $largeLines += "  task_id: noisy"
    $largeLines += "  status: logged"
    $largeLines += "  proves:"
    $largeLines += "  - historical evidence"
    $largeLines += "  does_not_prove:"
    $largeLines += "  - current readiness"
  }
  Set-Content -LiteralPath $verificationPath -Encoding UTF8 -Value $largeLines

  $oldDate = '2026-01-01'
  $openThreadLines = @('open_threads:')
  for ($i = 1; $i -le 7; $i++) {
    $openThreadLines += "- id: stale_open_$i"
    $openThreadLines += "  status: open"
    $openThreadLines += '  question: "stale?"'
    $openThreadLines += '  why_it_matters: "test"'
    $openThreadLines += "  owner: main_agent"
    $openThreadLines += "  gate: T1"
    $openThreadLines += "  blocks: []"
    $openThreadLines += "  evidence: []"
    $openThreadLines += "  unanswered_points: []"
    $openThreadLines += "  options:"
    $openThreadLines += '    recommended: ""'
    $openThreadLines += "    alternatives: []"
    $openThreadLines += '  next: ""'
    $openThreadLines += "  last_updated: '$oldDate'"
  }
  $openThreadLines += @"
- id: closed_1
  status: closed
  question: "closed"
  why_it_matters: "test"
  owner: main_agent
  gate: T1
  blocks: []
  evidence: []
  unanswered_points: []
  options:
    recommended: ""
    alternatives: []
  next: ""
  last_updated: '2026-06-20'
template:
  id: ""
"@
  Set-Content -LiteralPath (Join-Path $healthWarningRoot '.workflow\open_threads.yaml') -Encoding UTF8 -Value $openThreadLines

  Set-Content -LiteralPath (Join-Path $healthWarningRoot '.workflow\model-review-receipt-flat.yaml') -Encoding UTF8 -Value @'
task_id: flat-receipt
proves: []
does_not_prove: []
'@

  $healthJson = & powershell -NoProfile -ExecutionPolicy Bypass -File $validateScript -ProjectPath $healthWarningRoot -Json
  $healthValidation = $healthJson | ConvertFrom-Json
  Assert-True ($healthValidation.valid -eq $true) 'Workflow health warnings should not make the project invalid.'
  Assert-ValidationIssue -Validation $healthValidation -MessagePattern 'verification.yaml is large'
  Assert-ValidationIssue -Validation $healthValidation -MessagePattern 'open_threads.yaml has many open threads'
  Assert-ValidationIssue -Validation $healthValidation -MessagePattern 'stale open thread'
  Assert-ValidationIssue -Validation $healthValidation -MessagePattern 'flat receipt'
} finally {
  if (Test-Path -LiteralPath $healthWarningRoot -PathType Container) {
    $resolvedHealthTmp = (Resolve-Path -LiteralPath $healthWarningRoot).Path
    $tmpBase = [System.IO.Path]::GetTempPath()
    if ($resolvedHealthTmp.StartsWith($tmpBase, [System.StringComparison]::OrdinalIgnoreCase)) {
      Remove-Item -LiteralPath $resolvedHealthTmp -Recurse -Force
    }
  }
}

$lifecycleWarningRoot = Join-Path ([System.IO.Path]::GetTempPath()) ("agents-init-lifecycle-warning-test-" + [guid]::NewGuid().ToString('N'))
try {
  Copy-Item -LiteralPath $templateRoot -Destination $lifecycleWarningRoot -Recurse
  @'
main_thread:
  id: main
  role: main_agent_orchestrator
  status: active
workers:
- id: worker-ok
  status: no_output
  close_reason: "timeout"
  next_action: "retry with narrower task"
- id: worker-bad
  status: interrupted
  close_reason: ""
history: []
'@ | Set-Content -LiteralPath (Join-Path $lifecycleWarningRoot '.workflow\thread_registry.yaml') -Encoding UTF8

  $lifecycleJson = & powershell -NoProfile -ExecutionPolicy Bypass -File $validateScript -ProjectPath $lifecycleWarningRoot -Json
  $lifecycleValidation = $lifecycleJson | ConvertFrom-Json
  Assert-True ($lifecycleValidation.valid -eq $true) 'Lifecycle warnings should not make the project invalid.'
  Assert-ValidationIssue -Validation $lifecycleValidation -MessagePattern 'worker-bad.*without close_reason'
  Assert-ValidationIssue -Validation $lifecycleValidation -MessagePattern 'worker-bad.*without next_action'
} finally {
  if (Test-Path -LiteralPath $lifecycleWarningRoot -PathType Container) {
    $resolvedLifecycleTmp = (Resolve-Path -LiteralPath $lifecycleWarningRoot).Path
    $tmpBase = [System.IO.Path]::GetTempPath()
    if ($resolvedLifecycleTmp.StartsWith($tmpBase, [System.StringComparison]::OrdinalIgnoreCase)) {
      Remove-Item -LiteralPath $resolvedLifecycleTmp -Recurse -Force
    }
  }
}

$receiptApplyRoot = Join-Path ([System.IO.Path]::GetTempPath()) ("agents-init-receipt-apply-test-" + [guid]::NewGuid().ToString('N'))
try {
  Copy-Item -LiteralPath $templateRoot -Destination $receiptApplyRoot -Recurse

  @'
protocol_version: 1
main_thread:
  id: main
  role: main_agent_orchestrator
  status: active
workers:
- id: worker-apply
  source: codex_app
  lifecycle: one_shot
  type: disposable_worker
  role: test_worker
  task_id: APPLY-RECEIPT-001
  scope: "fixture"
  status: receipt_returned
  receipt_status: pending
  receipt_path: ""
  accepted_by_main_at: ""
  close_reason: ""
history: []
'@ | Set-Content -LiteralPath (Join-Path $receiptApplyRoot '.workflow\thread_registry.yaml') -Encoding UTF8

  $receiptPath = Join-Path $receiptApplyRoot '.workflow\worker-apply-receipt.yaml'
  @'
task_id: APPLY-RECEIPT-001
worker_id: worker-apply
worker_thread_id: worker-apply
lifecycle: one_shot
status: done
receipt_status: submitted
scope: "fixture"
files_read:
  - skill/agents-init/scripts/ingest-receipt.ps1
files_changed: []
commands_run:
  - command: "fixture command"
    exit_code: 0
thread_actions:
  created: false
artifact:
  - .workflow/worker-apply-receipt.yaml
evidence:
  - "fixture evidence"
proves:
  - "receipt apply fixture can be accepted"
decisions:
  locked: []
  proposed: []
open_threads: []
does_not_prove:
  - "UI acceptance"
risks:
  - "fixture only"
next_recommended_step:
  - "continue"
'@ | Set-Content -LiteralPath $receiptPath -Encoding UTF8

  $ingestScript = Join-Path $skillRoot 'scripts\ingest-receipt.ps1'
  $applyJson = & powershell -NoProfile -ExecutionPolicy Bypass -File $ingestScript -ProjectPath $receiptApplyRoot -ReceiptPath $receiptPath -Apply -Decision accepted -Json
  Assert-True ($LASTEXITCODE -eq 0) "ingest-receipt.ps1 -Apply must exit 0 for a valid accepted receipt. Output: $applyJson"
  $applyResult = $applyJson | ConvertFrom-Json
  Assert-True ($applyResult.applied -eq $true) 'ingest-receipt.ps1 -Apply must report applied=true.'

  $appliedVerification = Read-Text (Join-Path $receiptApplyRoot '.workflow\verification.yaml')
  $appliedRegistry = Read-Text (Join-Path $receiptApplyRoot '.workflow\thread_registry.yaml')
  Assert-True ($appliedVerification -match 'APPLY-RECEIPT-001' -and $appliedVerification -match 'receipt apply fixture can be accepted' -and $appliedVerification -match 'UI acceptance') 'Receipt apply must append task id, proves, and does_not_prove to verification.yaml.'
  Assert-True ($appliedRegistry -match 'id: worker-apply' -and $appliedRegistry -match 'status: receipt_accepted' -and $appliedRegistry -match 'receipt_status: accepted_by_main' -and $appliedRegistry -match 'accepted_by_main_at:') 'Receipt apply must update the matching worker record in thread_registry.yaml.'
  Assert-True ($appliedRegistry -match 'worker-apply-receipt.yaml') 'Receipt apply must record the accepted receipt path in thread_registry.yaml.'
  Assert-True ((($appliedRegistry -split "\r?\n").Count) -gt 8) 'Receipt apply must preserve thread_registry.yaml as multiline YAML, not collapse it into one line.'
  Assert-True (($appliedRegistry -match '(?m)^main_thread:\s*$') -and ($appliedRegistry -match '(?m)^workers:\s*$')) 'Receipt apply must preserve top-level thread_registry.yaml sections.'
  Assert-True ($appliedVerification -match '(?ms)proves:\s*\r?\n\s+- "receipt apply fixture can be accepted"\s*\r?\n\s+does_not_prove:' -or $appliedVerification -match '(?ms)proves:\s*\r?\n\s+- "receipt apply fixture can be accepted"\s*\r?\ndoes_not_prove:') 'Receipt apply must not let proves list swallow later YAML fields.'
  Assert-True ($appliedVerification -match '(?ms)does_not_prove:\s*\r?\n\s+- "UI acceptance"\s*\r?\n\s+risks:' -or $appliedVerification -match '(?ms)does_not_prove:\s*\r?\n\s+- "UI acceptance"\s*\r?\nrisks:') 'Receipt apply must not let does_not_prove list swallow risks or next steps.'

  $initWrapperScript = Join-Path $skillRoot 'scripts\init-agents.ps1'
  $wrapperJson = & powershell -NoProfile -ExecutionPolicy Bypass -File $initWrapperScript -ProjectPath $receiptApplyRoot -Mode ingest-receipt -ReceiptPath $receiptPath -ApplyReceipt -ReceiptDecision accepted
  Assert-True ($LASTEXITCODE -eq 0) "init-agents.ps1 -Mode ingest-receipt must expose receipt apply. Output: $wrapperJson"
  $wrapperResult = $wrapperJson | ConvertFrom-Json
  Assert-True ($wrapperResult.applied -eq $true) 'init-agents.ps1 wrapper must pass receipt apply through to ingest-receipt.ps1.'
} finally {
  if (Test-Path -LiteralPath $receiptApplyRoot -PathType Container) {
    $resolvedReceiptTmp = (Resolve-Path -LiteralPath $receiptApplyRoot).Path
    $tmpBase = [System.IO.Path]::GetTempPath()
    if ($resolvedReceiptTmp.StartsWith($tmpBase, [System.StringComparison]::OrdinalIgnoreCase)) {
      Remove-Item -LiteralPath $resolvedReceiptTmp -Recurse -Force
    }
  }
}

$closeoutHeadSyncRoot = Join-Path ([System.IO.Path]::GetTempPath()) ("agents-init-closeout-head-sync-test-" + [guid]::NewGuid().ToString('N'))
try {
  Copy-Item -LiteralPath $templateRoot -Destination $closeoutHeadSyncRoot -Recurse

  $closeoutScript = Join-Path $skillRoot 'scripts\closeout-workflow.ps1'
  $closeoutJson = & powershell -NoProfile -ExecutionPolicy Bypass -File $closeoutScript -ProjectPath $closeoutHeadSyncRoot -Reason route_change -TaskId CLOSEOUT-SYNC-001 -CurrentAuthority '.workflow/current.yaml' -Json
  Assert-True ($LASTEXITCODE -eq 0) "closeout-workflow.ps1 must exit 0 for a fixture route_change. Output: $closeoutJson"
  $closeoutResult = $closeoutJson | ConvertFrom-Json
  $closeoutReceiptPath = Join-Path $closeoutHeadSyncRoot ($closeoutResult.receipt -replace '/', '\')
  Assert-True (Test-Path -LiteralPath $closeoutReceiptPath -PathType Leaf) 'closeout-workflow.ps1 must write the reported closeout receipt path.'
  $closeoutReceipt = Read-Text $closeoutReceiptPath

  Assert-True ($closeoutReceipt -match 'head_mutations:') 'workflow closeout receipt must include head_mutations so each runtime head is explicitly updated or unchanged.'
  foreach ($head in @('current', 'task', 'open_threads', 'verification', 'authority_index', 'memory_points', 'thread_registry', 'session_recovery')) {
    Assert-True ($closeoutReceipt -match "(?ms)^\s{4}${head}:\s*\r?\n\s{6}status:\s*(updated|unchanged)") "workflow closeout receipt must mark $head as updated or unchanged."
  }
  Assert-True ($closeoutReceipt -match '(?ms)^\s{4}task:\s*\r?\n\s{6}status:\s*unchanged' -and $closeoutReceipt -match '(?ms)^\s{4}open_threads:\s*\r?\n\s{6}status:\s*unchanged') 'closeout-workflow.ps1 must explicitly mark task/open_threads unchanged when it does not mutate them.'
  Assert-True (($closeoutResult.updated -contains '.workflow/authority_index.yaml') -and ($closeoutResult.updated -contains '.workflow/verification.yaml') -and ($closeoutResult.updated -contains '.workflow/session-recovery-brief.md')) 'closeout-workflow.ps1 must report the core heads it actually updated.'
} finally {
  if (Test-Path -LiteralPath $closeoutHeadSyncRoot -PathType Container) {
    $resolvedCloseoutTmp = (Resolve-Path -LiteralPath $closeoutHeadSyncRoot).Path
    $tmpBase = [System.IO.Path]::GetTempPath()
    if ($resolvedCloseoutTmp.StartsWith($tmpBase, [System.StringComparison]::OrdinalIgnoreCase)) {
      Remove-Item -LiteralPath $resolvedCloseoutTmp -Recurse -Force
    }
  }
}

$binaryScratchRoot = Join-Path ([System.IO.Path]::GetTempPath()) ("agents-init-binary-scratch-test-" + [guid]::NewGuid().ToString('N'))
try {
  Copy-Item -LiteralPath $templateRoot -Destination $binaryScratchRoot -Recurse
  $scratchDir = Join-Path $binaryScratchRoot '.workflow\scratch'
  New-Item -ItemType Directory -Force -Path $scratchDir | Out-Null
  [System.IO.File]::WriteAllBytes((Join-Path $scratchDir 'visible-proof.png'), [byte[]](0x89, 0x50, 0x4E, 0x47, 0x00, 0x0D, 0x0A, 0x1A, 0x0A))
  [System.IO.File]::WriteAllBytes((Join-Path $scratchDir 'favicon.ico'), [byte[]](0x00, 0x00, 0x01, 0x00, 0x01, 0x00))

  $binaryScratchJson = & powershell -NoProfile -ExecutionPolicy Bypass -File $validateScript -ProjectPath $binaryScratchRoot -Json
  $binaryScratchValidation = $binaryScratchJson | ConvertFrom-Json
  Assert-True ($binaryScratchValidation.valid -eq $true) 'Binary screenshot/icon evidence in .workflow/scratch should not make workflow validation invalid.'
  $binaryScratchMessages = @($binaryScratchValidation.issues | ForEach-Object { $_.message })
  Assert-True (($binaryScratchMessages -match 'visible-proof\.png|favicon\.ico|not valid UTF-8|NUL bytes').Count -eq 0) 'Binary scratch artifacts should be skipped by workflow text encoding checks.'
} finally {
  if (Test-Path -LiteralPath $binaryScratchRoot -PathType Container) {
    $resolvedBinaryTmp = (Resolve-Path -LiteralPath $binaryScratchRoot).Path
    $tmpBase = [System.IO.Path]::GetTempPath()
    if ($resolvedBinaryTmp.StartsWith($tmpBase, [System.StringComparison]::OrdinalIgnoreCase)) {
      Remove-Item -LiteralPath $resolvedBinaryTmp -Recurse -Force
    }
  }
}

$integrationWarningRoot = Join-Path ([System.IO.Path]::GetTempPath()) ("agents-init-integration-warning-test-" + [guid]::NewGuid().ToString('N'))
try {
  Copy-Item -LiteralPath $templateRoot -Destination $integrationWarningRoot -Recurse
  $decisionPath = Join-Path $integrationWarningRoot '.workflow\templates\orchestration_decision.yaml'
  @'
id: test-integration
status: decided
product_system_fit_gate:
  required: true
  summary_only_failure: false
  evidence_bound_product_fit:
    original_product_anchors:
      - source: "test"
        proves:
          - "there is a global nav"
        does_not_prove:
          - "editor integration"
    native_interaction_grammar: {}
    capability_reuse_plan: {}
    candidate_insertion_points: []
    integration_fit:
      target_surface_level: global_nav
      claimed_integration_surface: "top-level nav"
      native_entry_point: "global nav"
      object_owner: "unclear"
      workflow_owner: "unclear"
      data_contract: "unclear"
      reused_capabilities: []
      anti_misclassification_check:
        placement_only: true
        global_nav_or_workspace_only: true
        editor_internal_integration_proven_by: ""
      first_slice_must_show:
        - ""
      status: passed
    first_visible_slice_acceptance: {}
    design_debate_receipt: {}
'@ | Set-Content -LiteralPath $decisionPath -Encoding UTF8

  $integrationJson = & powershell -NoProfile -ExecutionPolicy Bypass -File $validateScript -ProjectPath $integrationWarningRoot -Json
  $integrationValidation = $integrationJson | ConvertFrom-Json
  Assert-True ($integrationValidation.valid -eq $true) 'Integration-fit warnings should not make the project invalid.'
  Assert-ValidationIssue -Validation $integrationValidation -MessagePattern 'placement/entry alone does not prove editor or workflow integration'
  Assert-ValidationIssue -Validation $integrationValidation -MessagePattern 'without editor_internal_integration_proven_by or first_slice_must_show evidence'
} finally {
  if (Test-Path -LiteralPath $integrationWarningRoot -PathType Container) {
    $resolvedIntegrationTmp = (Resolve-Path -LiteralPath $integrationWarningRoot).Path
    $tmpBase = [System.IO.Path]::GetTempPath()
    if ($resolvedIntegrationTmp.StartsWith($tmpBase, [System.StringComparison]::OrdinalIgnoreCase)) {
      Remove-Item -LiteralPath $resolvedIntegrationTmp -Recurse -Force
    }
  }
}

if (-not [string]::IsNullOrWhiteSpace($SampleProject) -and (Test-Path -LiteralPath (Join-Path $SampleProject '.workflow\current.yaml') -PathType Leaf)) {
  $sampleCurrent = Read-Text (Join-Path $SampleProject '.workflow\current.yaml')
  Assert-True ($sampleCurrent -match '/image' -and $sampleCurrent -match '/canvas/ozon-suite' -and $sampleCurrent -match 'sidecar') 'Sample workflow current.yaml must foreground /image mainline vs /canvas/ozon-suite sidecar drift.'
}

[pscustomobject][ordered]@{
  status = 'passed'
  checked_files = $skillFiles.Count
  sample_project_checked = (-not [string]::IsNullOrWhiteSpace($SampleProject) -and (Test-Path -LiteralPath (Join-Path $SampleProject '.workflow\current.yaml') -PathType Leaf))
} | ConvertTo-Json -Depth 4
