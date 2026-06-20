[CmdletBinding()]
param(
  [Parameter(Mandatory = $true)]
  [string]$ProjectPath,

  [ValidateSet('auto', 'init', 'adopt', 'upgrade', 'status', 'menu', 'register-main', 'recover', 'validate', 'doctor', 'pressure-test', 'orchestrate', 'route-intent', 'dispatch-worker', 'ingest-receipt', 'save-state')]
  [string]$Mode = 'auto',

  [string]$MainThreadId = '',
  [string]$Prompt = '',
  [string]$TaskId = '',
  [string]$Task = '',
  [string]$Scope = '',
  [string]$ReceiptPath = '',

  [switch]$ApplyAgentEntry
)

$ErrorActionPreference = 'Stop'

function Convert-ToRelativePath {
  param(
    [Parameter(Mandatory = $true)][string]$Root,
    [Parameter(Mandatory = $true)][string]$Path
  )

  $rootFull = [System.IO.Path]::GetFullPath($Root).TrimEnd([System.IO.Path]::DirectorySeparatorChar, [System.IO.Path]::AltDirectorySeparatorChar)
  $pathFull = [System.IO.Path]::GetFullPath($Path)
  return $pathFull.Substring($rootFull.Length).TrimStart([System.IO.Path]::DirectorySeparatorChar, [System.IO.Path]::AltDirectorySeparatorChar)
}

if (-not (Test-Path -Path $ProjectPath -PathType Container)) {
  throw "ProjectPath does not exist or is not a directory: $ProjectPath"
}

$project = (Resolve-Path -Path $ProjectPath).Path
$skillRoot = Split-Path -Parent $PSScriptRoot
$template = Join-Path $skillRoot 'assets\project-template'

if (-not (Test-Path -Path $template -PathType Container)) {
  throw "Template directory missing: $template"
}

$hasAgents = Test-Path -Path (Join-Path $project 'AGENTS.md') -PathType Leaf
$hasWorkflow = Test-Path -Path (Join-Path $project '.workflow\current.yaml') -PathType Leaf

function Update-ThreadIdInFile {
  param(
    [Parameter(Mandatory = $true)][string]$Path,
    [Parameter(Mandatory = $true)][string]$ThreadId
  )

  if (-not (Test-Path -Path $Path -PathType Leaf)) {
    return $false
  }

  $text = Get-Content -Raw -Encoding UTF8 -LiteralPath $Path
  $text = [regex]::Replace($text, '(?m)^(\s*active_thread_id:\s*).*$', {
    param($match)
    $match.Groups[1].Value + '"' + $ThreadId + '"'
  })
  $text = [regex]::Replace($text, '(?m)^(\s*id:\s*)(current|[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12})\s*$', {
    param($match)
    $match.Groups[1].Value + $ThreadId
  })
  $text = [regex]::Replace($text, '(?m)^(\s*source:\s*)placeholder.*$', {
    param($match)
    $match.Groups[1].Value + 'user_provided'
  })
  Set-Content -LiteralPath $Path -Value $text -Encoding UTF8
  return $true
}

function Update-MainThreadRegistry {
  param(
    [Parameter(Mandatory = $true)][string]$Path,
    [Parameter(Mandatory = $true)][string]$ThreadId
  )

  if (-not (Test-Path -LiteralPath $Path -PathType Leaf)) {
    return $false
  }

  $text = Get-Content -Raw -Encoding UTF8 -LiteralPath $Path
  $oldId = $null
  $mainIdPattern = '(?ms)(^main_thread:\s*\r?\n(?:(?!^[^\s]).*\r?\n)*?\s+id:\s*)([^\r\n#]+)'
  $oldMatch = [regex]::Match($text, $mainIdPattern)
  if ($oldMatch.Success) {
    $oldId = $oldMatch.Groups[2].Value.Trim().Trim('"')
  }

  if ($oldId -and $oldId -ne 'current' -and $oldId -ne $ThreadId -and $text -match '(?m)^\s*history:\s*\[\]\s*$') {
    $historyBlock = @"
  history:
    - id: $oldId
      status: historical
      superseded_by: $ThreadId
      updated_at: "<update-on-use>"
"@
    $text = [regex]::Replace($text, '(?m)^\s*history:\s*\[\]\s*$', $historyBlock.TrimEnd())
  }

  $text = [regex]::Replace($text, '(?m)^(\s*active_thread_id:\s*).*$', {
    param($match)
    $match.Groups[1].Value + '"' + $ThreadId + '"'
  })
  $text = [regex]::Replace($text, $mainIdPattern, {
    param($match)
    return $match.Groups[1].Value + $ThreadId
  })
  $text = [regex]::Replace($text, '(?m)^(\s*source:\s*)placeholder.*$', {
    param($match)
    $match.Groups[1].Value + 'user_provided'
  })
  Set-Content -LiteralPath $Path -Value $text -Encoding UTF8
  return $true
}

function Add-TextBeforeMarker {
  param(
    [Parameter(Mandatory = $true)][string]$Text,
    [Parameter(Mandatory = $true)][string]$MarkerPattern,
    [Parameter(Mandatory = $true)][string]$InsertText
  )

  $match = [regex]::Match($Text, $MarkerPattern, [System.Text.RegularExpressions.RegexOptions]::Multiline)
  if (-not $match.Success) {
    return ($Text.TrimEnd() + "`r`n`r`n" + $InsertText.TrimEnd() + "`r`n")
  }
  return $Text.Substring(0, $match.Index) + $InsertText.TrimEnd() + "`r`n`r`n" + $Text.Substring($match.Index)
}

function Update-FileIfChanged {
  param(
    [Parameter(Mandatory = $true)][string]$Path,
    [Parameter(Mandatory = $true)][string]$Text
  )
  $old = if (Test-Path -LiteralPath $Path -PathType Leaf) { Get-Content -Raw -Encoding UTF8 -LiteralPath $Path } else { '' }
  if ($old -ne $Text) {
    Set-Content -LiteralPath $Path -Value $Text -Encoding UTF8
    return $true
  }
  return $false
}

function Test-LikelyMojibake {
  param([string]$Text)
  if (-not $Text) { return $false }
  $codes = @(0x951F, 0xFFFD, 0x6D93, 0x9438, 0x93C2, 0x9359, 0x9366, 0x93C8, 0x941E, 0x704F, 0x95C7, 0x951B, 0x93C0, 0x7035, 0x95AB, 0x6F36, 0x59AB, 0x6D60, 0x6F7F, 0x9286, 0x942A, 0x93AC, 0x95C4)
  foreach ($code in $codes) {
    if ($Text.IndexOf([char]$code) -ge 0) {
      return $true
    }
  }
  return $false
}

function Test-SuspiciousYamlDoubleQuote {
  param([string]$Text)
  if (-not $Text) {
    return $false
  }
  return $Text -match '(?m):\s*"[^"\r\n]*""'
}

function Get-DefaultModelPolicyText {
  return @'
updated_at: "<update-on-use>"

claude_review:
  default_model_alias: opus
  cheap_model_alias: sonnet
  default_execution_mode: capturable_cli_one_shot
  preferred_route: auto_discover_then_user_confirm
  fallback_route: capturable_cli_one_shot
  continuous_allowed: true
  max_review_turns_default: 2
  resume_policy: "Resume only when the next question depends on Claude's prior answer or role memory."
  close_policy: "Retire after receipt ingest, gate change, direction change, or quota concern."
  command_template_one_shot: "<claude_command> --safe-mode -p <packet> --model opus --output-format json --no-session-persistence"
  command_template_resume: "<claude_command> --safe-mode -p <follow-up> --model opus --output-format json --resume <session_id>"

route_discovery:
  candidate_commands:
    - cc2
    - claude
  detect_command:
    - "Get-Command cc2 -ErrorAction SilentlyContinue"
    - "Get-Command claude -ErrorAction SilentlyContinue"
  smoke_required_before_use: true
  smoke_command_template: "<candidate> --safe-mode -p \"agents-init Claude smoke. Reply with AGENTSINIT-CLAUDE-SMOKE.\" --model opus --output-format json --no-session-persistence"
  maestro_delegate_smoke_template: "maestro delegate --to claude --mode analysis --cd <project> \"Smoke test. Reply with AGENTSINIT-MAESTRO-CLAUDE-SMOKE.\""
  selection_policy:
    - "Prefer a project-approved wrapper such as cc2 when it smokes successfully."
    - "Use default claude only when it smokes successfully for the active profile."
    - "Use Maestro delegate only when raw output contains a task-relevant smoke token."
    - "If multiple candidates work, ask the user which profile/route should be project default."
    - "If no candidate works, mark Claude review blocked and continue with local multi-perspective analysis."

profile_policy:
  profile_label: ""
  env_var_name: CLAUDE_CONFIG_DIR
  env_value: ""
  allow_auto_profile_switch: false
  account_or_profile_switch_requires_user_confirmation: true
  do_not_store_secrets: true
  write_scope_default: project

overrides:
  no_claude_phrases:
    - "no Claude"
    - "Codex only"
    - "Chinese: do not use Claude"
  cheap_phrases:
    - "save quota"
    - "cheap Claude"
    - "sonnet"
    - "Chinese: save quota"
  opus_phrases:
    - "opus"
    - "4.8"
    - "important plan debate"
    - "Chinese: important plan debate"

must_record:
  - requested_model_alias
  - actual_model_reported_by_tool
  - execution_mode
  - session_id_if_resumed
  - why_resume_was_needed
'@
}

function Upgrade-AgentsInitV2 {
  param(
    [Parameter(Mandatory = $true)][string]$Project,
    [Parameter(Mandatory = $true)][string]$Template
  )

  $updated = New-Object System.Collections.Generic.List[string]
  $createdLocal = New-Object System.Collections.Generic.List[string]
  $skippedLocal = New-Object System.Collections.Generic.List[string]

  $requiredNewFiles = @(
    '.workflow\memory_points.yaml',
    '.workflow\model_policy.yaml',
    '.workflow\templates\adoption_salvage_report.yaml',
    '.workflow\templates\delegate_receipt.yaml',
    '.workflow\templates\handoff_receipt.yaml',
    '.workflow\templates\image_quality_review.yaml',
    '.workflow\templates\model_review_receipt.yaml',
    '.workflow\templates\multi_model_context_packet.md',
    '.workflow\templates\multi_perspective_review.yaml',
    '.workflow\templates\plan_pm_fde.yaml',
    '.workflow\templates\sample_decision.yaml',
    '.workflow\templates\session_recovery_brief.md',
    '.workflow\templates\task_brief.yaml',
    '.workflow\templates\ux_issue.yaml',
    '.workflow\templates\verification_receipt.yaml',
    'docs\dev-os\command-intent-map.md',
    'docs\dev-os\maestro-ralph-routing.md',
    'docs\dev-os\multi-codex-session-mode.md',
    'docs\dev-os\orchestration-loop.md',
    'docs\dev-os\README.md',
    'docs\dev-os\role-gates.md'
  )

  foreach ($relative in $requiredNewFiles) {
    $source = Join-Path $Template $relative
    $dest = Join-Path $Project $relative
    if (Test-Path -LiteralPath $dest -PathType Leaf) {
      $skippedLocal.Add($relative)
      continue
    }
    if (Test-Path -LiteralPath $source -PathType Leaf) {
      $parent = Split-Path -Parent $dest
      if (-not (Test-Path -LiteralPath $parent -PathType Container)) {
        New-Item -ItemType Directory -Path $parent -Force | Out-Null
      }
      Copy-Item -LiteralPath $source -Destination $dest
      $createdLocal.Add($relative)
    }
  }

  $orchPath = Join-Path $Project '.workflow\templates\orchestration_decision.yaml'
  if (Test-Path -LiteralPath $orchPath -PathType Leaf) {
    $text = Get-Content -Raw -Encoding UTF8 -LiteralPath $orchPath
    if ($text -notmatch '(?m)^\s*recovered_anchors:\s*$') {
      $block = @"
recovered_anchors:
  - source: ""
    proves:
      - ""
    does_not_prove:
      - ""
"@
      $text = Add-TextBeforeMarker -Text $text -MarkerPattern '(?m)^\s*semantic_signals:\s*$' -InsertText $block
    }
    if ($text -notmatch '(?m)^\s*root_diagnosis:\s*$') {
      $block = @"
root_diagnosis:
  recovered_mainline:
    - ""
  current_observed_artifact:
    - ""
  contradiction:
    - ""
  first_confirmation_question: ""
  status: not_needed | pending | stated | blocked
"@
      $text = Add-TextBeforeMarker -Text $text -MarkerPattern '(?m)^\s*semantic_signals:\s*$' -InsertText $block
    }
    if ($text -notmatch '(?m)^\s*decision_consequence_disclosure:\s*$') {
      $block = @"
decision_consequence_disclosure:
  required: false
  trigger:
    - product_shape_change | route_or_page_change | integration_mode_change | workflow_axis_change | human_gate_confirmation | visible_slice_approval
  visible_change:
    - ""
  integration_mode: core_integration | temporary_sidecar | workbench | adapter | import_export_path | analysis_only | unclear
  what_yes_authorizes:
    - ""
  what_yes_does_not_authorize:
    - ""
  rejected_or_deferred_paths:
    - ""
  rollback_or_reframe:
    - ""
  user_can_understand_without_reading_docs: false
  status: not_needed | pending | stated | blocked
"@
      $text = Add-TextBeforeMarker -Text $text -MarkerPattern '(?m)^\s*semantic_signals:\s*$' -InsertText $block
    }
    if ($text -notmatch '(?m)^\s*multi_perspective_review:\s*$') {
      $block = @"
multi_perspective_review:
  required: false
  reason:
    - fuzzy_requirement | long_task | old_project_salvage | ui_visible_gate | sample_or_image_gate | maestro_or_codex_app_orchestration | multi_model_review | repeated_failure
  artifact: .workflow/templates/multi_perspective_review.yaml
  views_required:
    - PM
    - FDE
    - UX_visible_acceptance
    - Workflow_context_engineering
    - Maestro_Codex_App_orchestration
    - Risk_overengineering
  status: not_needed | pending | completed | blocked
"@
      $text = Add-TextBeforeMarker -Text $text -MarkerPattern '(?m)^\s*human_gates:\s*$' -InsertText $block
    }
    if ($text -notmatch '(?m)^\s*knowledge_lifecycle:\s*$') {
      $block = @"
knowledge_lifecycle:
  update_current:
    - ""
  update_task:
    - ""
  open_threads_to_close:
    - ""
  open_threads_to_add_or_keep:
    - ""
  memory_points_to_add:
    - ""
  memory_points_to_supersede:
    - ""
  promote_to_spec:
    - category: ""
      title: ""
      reason: ""
  promote_to_knowhow:
    - type: ""
      title: ""
      reason: ""
  kg_actions:
    - none | index | sync | search | context
  archive_or_receipts:
    - ""
  does_not_update:
    - ""
"@
      $text = Add-TextBeforeMarker -Text $text -MarkerPattern '(?m)^\s*human_gates:\s*$' -InsertText $block
    }
    if (Update-FileIfChanged -Path $orchPath -Text $text) {
      $updated.Add('.workflow\templates\orchestration_decision.yaml')
    }
  }

  $workerPath = Join-Path $Project '.workflow\templates\worker_receipt.yaml'
  if (Test-Path -LiteralPath $workerPath -PathType Leaf) {
    $text = Get-Content -Raw -Encoding UTF8 -LiteralPath $workerPath
    if ($text -notmatch '(?m)^\s*lifecycle:\s*') {
      $text = [regex]::Replace($text, '(?m)^(\s*worker_id:.*\r?\n)', "`$1worker_thread_id: `"`"`r`nlifecycle: one_shot | continuous`r`nreceipt_status: submitted | accepted | rejected`r`n", 1)
    }
    if ($text -notmatch '(?m)^\s*thread_actions:\s*$') {
      $block = @"
thread_actions:
  created: false
  read_by_main: false
  archived_or_closed: false
  continuous_session_kept_active: false
"@
      $text = Add-TextBeforeMarker -Text $text -MarkerPattern '(?m)^\s*artifact:\s*$' -InsertText $block
    }
    if ($text -notmatch '(?m)^\s*main_agent_ingest:\s*$') {
      $block = @"
main_agent_ingest:
  accepted: false
  reason: ""
  workflow_updates:
    - ""
  receipt_archived_to: ""
"@
      $text = $text.TrimEnd() + "`r`n`r`n" + $block.TrimEnd() + "`r`n"
    }
    if (Update-FileIfChanged -Path $workerPath -Text $text) {
      $updated.Add('.workflow\templates\worker_receipt.yaml')
    }
  }

  $multiModelPacketPath = Join-Path $Project '.workflow\templates\multi_model_context_packet.md'
  if (Test-Path -LiteralPath $multiModelPacketPath -PathType Leaf) {
    $text = Get-Content -Raw -Encoding UTF8 -LiteralPath $multiModelPacketPath
    if ($text -notmatch '(?m)^\s*requested_model_alias:\s*opus\s*$') {
      $block = @"
requested_model_alias: opus
fallback_model_alias: sonnet
actual_model_expected_from_tool: true
"@
      $text = Add-TextBeforeMarker -Text $text -MarkerPattern '(?m)^\s*quota_policy:\s*$' -InsertText $block
    }
    if ($text -notmatch '(?m)^\s*close_condition:\s*$') {
      $block = @"
  close_condition:
    - receipt_accepted
    - gate_changed
    - user_changed_direction
    - quota_concern
"@
      $text = Add-TextBeforeMarker -Text $text -MarkerPattern '(?m)^\s*must_not_decide:\s*$' -InsertText $block
    }
    if (Update-FileIfChanged -Path $multiModelPacketPath -Text $text) {
      $updated.Add('.workflow\templates\multi_model_context_packet.md')
    }
  }

  $modelReviewReceiptPath = Join-Path $Project '.workflow\templates\model_review_receipt.yaml'
  if (Test-Path -LiteralPath $modelReviewReceiptPath -PathType Leaf) {
    $text = Get-Content -Raw -Encoding UTF8 -LiteralPath $modelReviewReceiptPath
    if ($text -notmatch '(?m)^\s*requested_model_alias:\s*') {
      $text = [regex]::Replace($text, '(?m)^(\s*tool:\s*.*\r?\n)', "`$1  requested_model_alias: `"`"`r`n  fallback_model_alias: `"`"`r`n", 1)
    }
    if ($text -notmatch '(?m)^\s*actual_model_verified_from_output:\s*') {
      $text = [regex]::Replace($text, '(?m)^(\s*session_or_exec_id:\s*.*\r?\n)', "`$1  actual_model_verified_from_output: false`r`n", 1)
    }
    if (Update-FileIfChanged -Path $modelReviewReceiptPath -Text $text) {
      $updated.Add('.workflow\templates\model_review_receipt.yaml')
    }
  }

  $modelPolicyPath = Join-Path $Project '.workflow\model_policy.yaml'
  if (Test-Path -LiteralPath $modelPolicyPath -PathType Leaf) {
    $text = Get-Content -Raw -Encoding UTF8 -LiteralPath $modelPolicyPath
    if ((Test-LikelyMojibake $text) -or (Test-SuspiciousYamlDoubleQuote $text)) {
      $text = Get-DefaultModelPolicyText
    }
    if ($text -notmatch '(?m)^\s*preferred_route:\s*') {
      $text = [regex]::Replace($text, '(?m)^(\s*default_execution_mode:\s*.*\r?\n)', "`$1  preferred_route: auto_discover_then_user_confirm`r`n  fallback_route: capturable_cli_one_shot`r`n", 1)
    }
    $text = [regex]::Replace(
      $text,
      '(?m)^\s*smoke_command_template:\s*.*$',
      '  smoke_command_template: "<candidate> --safe-mode -p \"agents-init Claude smoke. Reply with AGENTSINIT-CLAUDE-SMOKE.\" --model opus --output-format json --no-session-persistence"'
    )
    $text = [regex]::Replace(
      $text,
      '(?m)^\s*maestro_delegate_smoke_template:\s*.*$',
      '  maestro_delegate_smoke_template: "maestro delegate --to claude --mode analysis --cd <project> \"Smoke test. Reply with AGENTSINIT-MAESTRO-CLAUDE-SMOKE.\""'
    )
    if ($text -notmatch '(?m)^\s*route_discovery:\s*$') {
      $block = @"
route_discovery:
  candidate_commands:
    - cc2
    - claude
  detect_command:
    - "Get-Command cc2 -ErrorAction SilentlyContinue"
    - "Get-Command claude -ErrorAction SilentlyContinue"
  smoke_required_before_use: true
  smoke_command_template: "<candidate> --safe-mode -p \`"agents-init Claude smoke. Reply with AGENTSINIT-CLAUDE-SMOKE.\`" --model opus --output-format json --no-session-persistence"
  maestro_delegate_smoke_template: "maestro delegate --to claude --mode analysis --cd <project> \`"Smoke test. Reply with AGENTSINIT-MAESTRO-CLAUDE-SMOKE.\`""
  selection_policy:
    - "Prefer a project-approved wrapper such as cc2 when it smokes successfully."
    - "Use default claude only when it smokes successfully for the active profile."
    - "Use Maestro delegate only when raw output contains a task-relevant smoke token."
    - "If multiple candidates work, ask the user which profile/route should be project default."
    - "If no candidate works, mark Claude review blocked and continue with local multi-perspective analysis."
"@
      $text = $text.TrimEnd() + "`r`n`r`n" + $block.TrimEnd() + "`r`n"
    }
    if ($text -notmatch '(?m)^\s*profile_policy:\s*$') {
      $block = @"
profile_policy:
  profile_label: ""
  env_var_name: CLAUDE_CONFIG_DIR
  env_value: ""
  allow_auto_profile_switch: false
  account_or_profile_switch_requires_user_confirmation: true
  do_not_store_secrets: true
  write_scope_default: project
"@
      $text = $text.TrimEnd() + "`r`n`r`n" + $block.TrimEnd() + "`r`n"
    }
    if (Update-FileIfChanged -Path $modelPolicyPath -Text $text) {
      $updated.Add('.workflow\model_policy.yaml')
    }
  }

  $threadPath = Join-Path $Project '.workflow\thread_registry.yaml'
  if (Test-Path -LiteralPath $threadPath -PathType Leaf) {
    $text = Get-Content -Raw -Encoding UTF8 -LiteralPath $threadPath
    $text = $text -replace '(?m)^(\s*)type:\s*disposable\s*$', '$1type: one_shot'
    $text = $text -replace '(?m)^(\s*)default_type:\s*disposable\s*$', '$1default_type: one_shot'
    $text = $text -replace '(?m)^(\s*)type:\s*durable\s*$', '$1type: continuous'
    if ($text -notmatch '(?m)^\s*lifecycle:\s*') {
      $text = [regex]::Replace($text, '(?m)^(\s*)type:\s*(one_shot|continuous).*(\r?\n)', {
        param($match)
        $match.Value + $match.Groups[1].Value + 'lifecycle: ' + $match.Groups[2].Value + $match.Groups[3].Value
      }, 1)
    }
    if ($text -notmatch '(?ms)^\s*worker_record_template:\s*\r?\n(?:(?!^[^\s]).*\r?\n)*?\s+conflicts_with:\s*') {
      $text = [regex]::Replace($text, '(?ms)(^\s*worker_record_template:\s*\r?\n(?:(?!^[^\s]).*\r?\n)*?\s+must_not_edit:\s*\r?\n(?:\s+- .*\r?\n)*)', "`$1  conflicts_with: []`r`n", 1)
    }
    if ($text -notmatch '(?ms)^\s*example_worker:\s*\r?\n(?:(?!^[^\s]).*\r?\n)*?\s+conflicts_with:\s*') {
      $text = [regex]::Replace($text, '(?ms)(^\s*example_worker:\s*\r?\n(?:(?!^[^\s]).*\r?\n)*?\s+must_not_edit:\s*\r?\n(?:\s+- .*\r?\n)*)', "`$1  conflicts_with: []`r`n", 1)
    }
    if (Update-FileIfChanged -Path $threadPath -Text $text) {
      $updated.Add('.workflow\thread_registry.yaml')
    }
  }

  return [ordered]@{
    created = @($createdLocal)
    updated = @($updated)
    skipped_existing = @($skippedLocal)
  }
}

if ($Mode -eq 'auto') {
  if (-not $hasAgents -and -not $hasWorkflow) {
    $Mode = 'init'
  } elseif ($hasWorkflow) {
    $Mode = 'upgrade'
  } else {
    $Mode = 'adopt'
  }
}

if ($Mode -eq 'menu') {
  $menu = [ordered]@{
    project = $project
    mode = 'menu'
    natural_language_menu = @(
      'Init/adopt project: create or upgrade a recoverable .workflow.',
      'Recover context: report goal, gate, evidence, open issues, and next step.',
      'Clarify fuzzy intent: restate intent, find uncertainty, ask 1-3 upstream questions.',
      'Plan/blueprint: PM + FDE plan, old-project salvage, insertion plan.',
      'Workers: dispatch bounded Codex workers and ingest receipts.',
      'Maestro/Ralph: route lifecycle/delegate work after gates are clear.',
      'Claude/multi-model: build a compact packet, run a receipt-backed second view.',
      'UI/sample/image gate: require visible evidence and user acceptance.',
      'Self-update: pull latest agents-init and optionally upgrade this project.',
      'Save handoff: write recoverable state before compression or handoff.'
    )
    example_user_prompts = @(
      'agents-init menu',
      'Recover this project and report goal/gate/evidence/next action.',
      'The direction feels wrong; recover context before asking questions.',
      'This old project/worktree failed; do salvage and insertion plan first.',
      'Update agents-init, then upgrade this project workflow.',
      'Open two bounded workers to inspect logs and docs separately.',
      'Ask Claude to challenge this plan, but recover context first.'
    )
    state_files = [ordered]@{
      agents_init = Join-Path $project '.workflow\agents-init.yaml'
      current = Join-Path $project '.workflow\current.yaml'
      thread_registry = Join-Path $project '.workflow\thread_registry.yaml'
      worker_receipt = Join-Path $project '.workflow\templates\worker_receipt.yaml'
    }
    commands = @(
      '$agents-init recover',
      '$agents-init doctor',
      '$agents-init validate',
      '$agents-init pressure-test',
      '$agents-init orchestrate',
      '$agents-init grill',
      '$agents-init brainstorm',
      '$agents-init blueprint',
      '$agents-init plan',
      '$agents-init register-main',
      '$agents-init dispatch-worker',
      '$agents-init ingest-receipt',
      '$agents-init route-maestro',
      '$agents-init route-intent',
      '$agents-init self-update',
      '$agents-init save-state'
    )
    script_examples = @(
      'powershell -NoProfile -ExecutionPolicy Bypass -File <skill>\scripts\init-agents.ps1 -ProjectPath <project> -Mode auto',
      'powershell -NoProfile -ExecutionPolicy Bypass -File <skill>\scripts\init-agents.ps1 -ProjectPath <project> -Mode recover',
      'powershell -NoProfile -ExecutionPolicy Bypass -File <skill>\scripts\init-agents.ps1 -ProjectPath <project> -Mode validate',
      'powershell -NoProfile -ExecutionPolicy Bypass -File <skill>\scripts\init-agents.ps1 -ProjectPath <project> -Mode doctor',
      'powershell -NoProfile -ExecutionPolicy Bypass -File <skill>\scripts\init-agents.ps1 -ProjectPath <project> -Mode pressure-test',
      'powershell -NoProfile -ExecutionPolicy Bypass -File <skill>\scripts\init-agents.ps1 -ProjectPath <project> -Mode orchestrate -Prompt "the direction feels off"',
      'powershell -NoProfile -ExecutionPolicy Bypass -File <skill>\scripts\init-agents.ps1 -ProjectPath <project> -Mode route-intent -Prompt "I am fuzzy; help clarify"',
      'powershell -NoProfile -ExecutionPolicy Bypass -File <skill>\scripts\update-agents-init.ps1 -ProjectPath <project>',
      'powershell -NoProfile -ExecutionPolicy Bypass -File <skill>\scripts\init-agents.ps1 -ProjectPath <project> -Mode dispatch-worker -TaskId T3 -Task "analyze old branch" -Scope "read-only docs"',
      'powershell -NoProfile -ExecutionPolicy Bypass -File <skill>\scripts\init-agents.ps1 -ProjectPath <project> -Mode ingest-receipt -ReceiptPath <receipt.yaml>',
      'powershell -NoProfile -ExecutionPolicy Bypass -File <skill>\scripts\init-agents.ps1 -ProjectPath <project> -Mode save-state',
      'powershell -NoProfile -ExecutionPolicy Bypass -File <skill>\scripts\init-agents.ps1 -ProjectPath <project> -Mode register-main -MainThreadId <thread-id>'
    )
  }
  $menu | ConvertTo-Json -Depth 8
  exit 0
}

if ($Mode -eq 'recover') {
  $recoverScript = Join-Path $PSScriptRoot 'recover-agents.ps1'
  & $recoverScript -ProjectPath $project -Json
  exit $LASTEXITCODE
}

if ($Mode -eq 'validate') {
  $validateScript = Join-Path $PSScriptRoot 'validate-workflow.ps1'
  & $validateScript -ProjectPath $project -Json
  exit $LASTEXITCODE
}

if ($Mode -eq 'doctor') {
  $doctorScript = Join-Path $PSScriptRoot 'doctor-agents.ps1'
  & $doctorScript -ProjectPath $project -Json
  exit $LASTEXITCODE
}

if ($Mode -eq 'pressure-test') {
  $pressureScript = Join-Path $PSScriptRoot 'pressure-test-agents.ps1'
  & $pressureScript -ProjectPath $project -Json
  exit $LASTEXITCODE
}

if ($Mode -eq 'route-intent') {
  if ([string]::IsNullOrWhiteSpace($Prompt)) {
    throw "Mode route-intent requires -Prompt."
  }
  $routeScript = Join-Path $PSScriptRoot 'route-intent.ps1'
  & $routeScript -ProjectPath $project -Prompt $Prompt -Json
  exit $LASTEXITCODE
}

if ($Mode -eq 'orchestrate') {
  if ([string]::IsNullOrWhiteSpace($Prompt)) {
    throw "Mode orchestrate requires -Prompt."
  }
  $recoverScript = Join-Path $PSScriptRoot 'recover-agents.ps1'
  $routeScript = Join-Path $PSScriptRoot 'route-intent.ps1'
  $recovered = & $recoverScript -ProjectPath $project -Json
  $weakRoute = & $routeScript -ProjectPath $project -Prompt $Prompt -Json
  [ordered]@{
    project = $project
    mode = 'orchestrate'
    prompt = $Prompt
    instruction = 'Main agent must use semantic reasoning, not keyword routing alone. Read references/main-agent-orchestration.md and write/update .workflow/templates/orchestration_decision.yaml or an equivalent decision note.'
    recovered_state = ($recovered | ConvertFrom-Json)
    weak_route_hint = ($weakRoute | ConvertFrom-Json)
    required_decision_fields = @(
      'user_words',
      'recovered_state',
      'recovered_anchors',
      'root_diagnosis',
      'decision_consequence_disclosure',
      'semantic_signals',
      'current_gate',
      'recommended_route',
      'why_not_direct',
      'maestro_use',
      'codex_app_workers',
      'multi_perspective_review',
      'knowledge_lifecycle',
      'human_gates',
      'next_action',
      'does_not_prove'
    )
  } | ConvertTo-Json -Depth 12
  exit 0
}

if ($Mode -eq 'dispatch-worker') {
  if ([string]::IsNullOrWhiteSpace($TaskId) -or [string]::IsNullOrWhiteSpace($Task)) {
    throw "Mode dispatch-worker requires -TaskId and -Task."
  }
  $workerScript = Join-Path $PSScriptRoot 'make-worker-prompt.ps1'
  & $workerScript -ProjectPath $project -TaskId $TaskId -Task $Task -Scope $Scope -WriteFile -Json
  exit $LASTEXITCODE
}

if ($Mode -eq 'ingest-receipt') {
  if ([string]::IsNullOrWhiteSpace($ReceiptPath)) {
    throw "Mode ingest-receipt requires -ReceiptPath."
  }
  $ingestScript = Join-Path $PSScriptRoot 'ingest-receipt.ps1'
  & $ingestScript -ProjectPath $project -ReceiptPath $ReceiptPath -Json
  exit $LASTEXITCODE
}

if ($Mode -eq 'save-state') {
  $saveScript = Join-Path $PSScriptRoot 'save-state.ps1'
  & $saveScript -ProjectPath $project -Json
  exit $LASTEXITCODE
}

if ($Mode -eq 'register-main') {
  if ([string]::IsNullOrWhiteSpace($MainThreadId)) {
    throw "Mode register-main requires -MainThreadId."
  }

  $agentsInitPath = Join-Path $project '.workflow\agents-init.yaml'
  $threadRegistryPath = Join-Path $project '.workflow\thread_registry.yaml'

  $updated = @()
  if (Update-ThreadIdInFile -Path $agentsInitPath -ThreadId $MainThreadId) {
    $updated += '.workflow\agents-init.yaml'
  }
  if (Update-MainThreadRegistry -Path $threadRegistryPath -ThreadId $MainThreadId) {
    $updated += '.workflow\thread_registry.yaml'
  }

  [ordered]@{
    project = $project
    mode = 'register-main'
    main_thread_id = $MainThreadId
    updated = $updated
    note = 'If an old concrete main id was present, the script attempts to record it in history.'
  } | ConvertTo-Json -Depth 8
  exit 0
}

$created = New-Object System.Collections.Generic.List[string]
$skipped = New-Object System.Collections.Generic.List[string]
$updated = @()

if ($Mode -eq 'upgrade') {
  $upgradeResult = Upgrade-AgentsInitV2 -Project $project -Template $template
  foreach ($item in $upgradeResult.created) { $created.Add($item) }
  foreach ($item in $upgradeResult.skipped_existing) { $skipped.Add($item) }
  $updated = @($upgradeResult.updated)
} elseif ($Mode -ne 'status') {
  $files = Get-ChildItem -Path $template -Recurse -File -Force
  foreach ($file in $files) {
    $relative = Convert-ToRelativePath -Root $template -Path $file.FullName
    $dest = Join-Path $project $relative
    if (Test-Path -Path $dest -PathType Leaf) {
      $skipped.Add($relative)
      continue
    }

    $parent = Split-Path -Parent $dest
    if (-not (Test-Path -Path $parent -PathType Container)) {
      New-Item -ItemType Directory -Path $parent -Force | Out-Null
    }
    Copy-Item -LiteralPath $file.FullName -Destination $dest
    $created.Add($relative)
  }
}

$agentEntry = @'

## Agents Init Router

If this project has `.workflow/current.yaml`, read it before coding. For fuzzy requirements, UI/UX, sample selection, generated image quality, business mainline, or long tasks, use the project-local Agents Init files:

```text
.workflow/current.yaml
.workflow/agents-init.yaml
.workflow/task.yaml
.workflow/open_threads.yaml
.workflow/verification.yaml
.workflow/thread_registry.yaml
docs/dev-os/README.md
docs/dev-os/command-intent-map.md
docs/dev-os/role-gates.md
```

Main agent owns clarification, orchestration, worker receipts, context recovery, and final judgment. Existing files must not be overwritten without explicit user approval.
'@

$agentsPath = Join-Path $project 'AGENTS.md'
$agentEntryStatus = 'not_applicable'

if (Test-Path -Path $agentsPath -PathType Leaf) {
    $agentsText = Get-Content -Raw -Encoding UTF8 -LiteralPath $agentsPath
  if ($agentsText -match 'Agents Init Router|Agents Init Project Router|agents-init-usage-card\.md|Personal Dev OS Router|Personal Dev OS Project Router') {
    $agentEntryStatus = 'already_present'
  } elseif ($ApplyAgentEntry) {
    Add-Content -LiteralPath $agentsPath -Value $agentEntry -Encoding UTF8
    $agentEntryStatus = 'appended'
  } else {
    $agentEntryStatus = 'suggested_only'
  }
}

$result = [ordered]@{
  project = $project
  mode = $Mode
  created = @($created)
  updated = @($updated)
  skipped_existing = @($skipped)
  agent_entry_status = $agentEntryStatus
  agent_entry_snippet = if ($agentEntryStatus -eq 'suggested_only') { $agentEntry.Trim() } else { $null }
  next_steps = @(
    'Read or create .workflow/current.yaml.',
    'If this is an existing project, classify old TODO/docs as rule, plan, contract, evidence, receipt, knowhow, rejected_path, or unresolved.',
    'For long tasks, maintain open_threads and verification before implementation.',
    'Use worker/delegate receipts for multi-Codex, subagent, or Maestro work.',
    'Run -Mode validate before claiming the workflow is configured.'
  )
}

$result | ConvertTo-Json -Depth 8
