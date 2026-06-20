[CmdletBinding()]
param(
  [Parameter(Mandatory = $true)]
  [string]$ProjectPath,

  [switch]$Json
)

$ErrorActionPreference = 'Stop'

function Read-TextOrEmpty {
  param([Parameter(Mandatory = $true)][string]$Path)
  if (Test-Path -LiteralPath $Path -PathType Leaf) {
    return Get-Content -Raw -Encoding UTF8 -LiteralPath $Path
  }
  return ''
}

function Test-PlaceholderText {
  param([string]$Text)
  return $Text -match '<[^>\r\n]+>' -or $Text -match '(?m)^\s*(active_task|mission|next_action):\s*(null|""|''''|\s*)$'
}

function Test-NonEmptyField {
  param([string]$Text, [string]$Field)
  return $Text -match "(?m)^\s*$([regex]::Escape($Field))\s*:\s*(?!\s*(null|$|`"`"|''|<))\S+"
}

function Add-Issue {
  param(
    [Parameter(Mandatory = $true)][string]$Level,
    [Parameter(Mandatory = $true)][string]$Message,
    [string]$File = ''
  )
  $script:issues += [ordered]@{
    level = $Level
    message = $Message
    file = $File
  }
}

if (-not (Test-Path -LiteralPath $ProjectPath -PathType Container)) {
  throw "ProjectPath does not exist or is not a directory: $ProjectPath"
}

$project = (Resolve-Path -LiteralPath $ProjectPath).Path
$workflow = Join-Path $project '.workflow'
$issues = @()

$requiredFiles = @(
  '.workflow/current.yaml',
  '.workflow/agents-init.yaml',
  '.workflow/task.yaml',
  '.workflow/open_threads.yaml',
  '.workflow/verification.yaml',
  '.workflow/thread_registry.yaml',
  '.workflow/memory_points.yaml',
  '.workflow/model_policy.yaml',
  '.workflow/templates/worker_receipt.yaml',
  '.workflow/templates/task_brief.yaml',
  '.workflow/templates/delegate_receipt.yaml',
  '.workflow/templates/handoff_receipt.yaml',
  '.workflow/templates/verification_receipt.yaml',
  '.workflow/templates/adoption_salvage_report.yaml',
  '.workflow/templates/ux_issue.yaml',
  '.workflow/templates/sample_decision.yaml',
  '.workflow/templates/image_quality_review.yaml',
  '.workflow/templates/orchestration_decision.yaml',
  '.workflow/templates/multi_model_context_packet.md',
  '.workflow/templates/model_review_receipt.yaml',
  '.workflow/templates/multi_perspective_review.yaml',
  'docs/dev-os/command-intent-map.md',
  'docs/dev-os/multi-codex-session-mode.md'
)

foreach ($relative in $requiredFiles) {
  $path = Join-Path $project $relative
  if (-not (Test-Path -LiteralPath $path -PathType Leaf)) {
    Add-Issue -Level 'error' -Message "Missing required workflow file: $relative" -File $relative
  }
}

$currentPath = Join-Path $project '.workflow/current.yaml'
$taskPath = Join-Path $project '.workflow/task.yaml'
$verificationPath = Join-Path $project '.workflow/verification.yaml'
$threadPath = Join-Path $project '.workflow/thread_registry.yaml'
$memoryPointsPath = Join-Path $project '.workflow/memory_points.yaml'
$modelPolicyPath = Join-Path $project '.workflow/model_policy.yaml'
$workerReceiptPath = Join-Path $project '.workflow/templates/worker_receipt.yaml'
$orchestrationDecisionPath = Join-Path $project '.workflow/templates/orchestration_decision.yaml'
$multiPerspectiveReviewPath = Join-Path $project '.workflow/templates/multi_perspective_review.yaml'
$multiModelPacketPath = Join-Path $project '.workflow/templates/multi_model_context_packet.md'
$modelReviewReceiptPath = Join-Path $project '.workflow/templates/model_review_receipt.yaml'
$dispatchDir = Join-Path $project '.workflow/dispatch'

$current = Read-TextOrEmpty $currentPath
$task = Read-TextOrEmpty $taskPath
$verification = Read-TextOrEmpty $verificationPath
$thread = Read-TextOrEmpty $threadPath
$memoryPoints = Read-TextOrEmpty $memoryPointsPath
$modelPolicy = Read-TextOrEmpty $modelPolicyPath
$workerReceipt = Read-TextOrEmpty $workerReceiptPath
$orchestrationDecision = Read-TextOrEmpty $orchestrationDecisionPath
$multiPerspectiveReview = Read-TextOrEmpty $multiPerspectiveReviewPath
$multiModelPacket = Read-TextOrEmpty $multiModelPacketPath
$modelReviewReceipt = Read-TextOrEmpty $modelReviewReceiptPath

if ($current -and $current -notmatch '(?m)^\s*current_gate:\s*\S+') {
  Add-Issue -Level 'error' -Message 'current.yaml must include current_gate.' -File '.workflow/current.yaml'
}
if ($current -and $current -notmatch '(?m)^\s*next_action:\s*\S+') {
  Add-Issue -Level 'warning' -Message 'current.yaml should include next_action.' -File '.workflow/current.yaml'
}
if ($current -and (Test-PlaceholderText $current)) {
  Add-Issue -Level 'warning' -Message 'current.yaml still contains placeholders or empty/null fields; this is static/template-ready, not recovered-task-ready.' -File '.workflow/current.yaml'
}
if ($current -and -not (Test-NonEmptyField -Text $current -Field 'mission')) {
  Add-Issue -Level 'warning' -Message 'current.yaml should include a concrete mission before claiming long-task readiness.' -File '.workflow/current.yaml'
}
if ($task -and $task -notmatch '(?m)^\s*active_task:') {
  Add-Issue -Level 'warning' -Message 'task.yaml should include active_task.' -File '.workflow/task.yaml'
}
if ($task -and $task -match '(?m)^\s*active_task:\s*(null|""|'''')\s*$') {
  Add-Issue -Level 'warning' -Message 'task.yaml has no active_task; do not claim an executable task is ready.' -File '.workflow/task.yaml'
}
if ($task -and $task -match '(?m)^\s*active_task:\s*$' -and $task -notmatch '(?ms)^\s*active_task:\s*\r?\n(?:\s+[^\r\n]*\r?\n)*?\s+id:\s*\S+') {
  Add-Issue -Level 'warning' -Message 'task.yaml active_task block should include an id.' -File '.workflow/task.yaml'
}
if ($verification -and ($verification -notmatch 'proves:' -or $verification -notmatch 'does_not_prove:')) {
  Add-Issue -Level 'error' -Message 'verification.yaml must include proves and does_not_prove fields.' -File '.workflow/verification.yaml'
}
if ($verification -and $verification -match '(?m)^\s*verification_log:\s*\[\]\s*$') {
  Add-Issue -Level 'warning' -Message 'verification.yaml has no verification entries; this does not prove implementation or acceptance.' -File '.workflow/verification.yaml'
}
if ($workerReceipt -and ($workerReceipt -notmatch 'proves:' -or $workerReceipt -notmatch 'does_not_prove:')) {
  Add-Issue -Level 'error' -Message 'worker_receipt.yaml must include proves and does_not_prove.' -File '.workflow/templates/worker_receipt.yaml'
}
if ($workerReceipt -and $workerReceipt -notmatch '(?m)^\s*lifecycle:\s*') {
  Add-Issue -Level 'warning' -Message 'worker_receipt.yaml should include lifecycle: one_shot | continuous.' -File '.workflow/templates/worker_receipt.yaml'
}
if ($orchestrationDecision -and $orchestrationDecision -notmatch '(?m)^\s*multi_perspective_review:\s*') {
  Add-Issue -Level 'warning' -Message 'orchestration_decision.yaml should include multi_perspective_review routing fields.' -File '.workflow/templates/orchestration_decision.yaml'
}
if ($orchestrationDecision -and $orchestrationDecision -notmatch '(?m)^\s*root_diagnosis:\s*') {
  Add-Issue -Level 'warning' -Message 'orchestration_decision.yaml should include root_diagnosis so context-referenced prompts diagnose the upstream contradiction before questions.' -File '.workflow/templates/orchestration_decision.yaml'
}
if ($orchestrationDecision -and $orchestrationDecision -notmatch '(?m)^\s*decision_consequence_disclosure:\s*') {
  Add-Issue -Level 'warning' -Message 'orchestration_decision.yaml should include decision_consequence_disclosure so confirmations expose page/route/workflow consequences before the user approves.' -File '.workflow/templates/orchestration_decision.yaml'
}
if ($multiPerspectiveReview) {
  foreach ($view in @('PM', 'FDE', 'UX_visible_acceptance', 'Workflow_context_engineering', 'Maestro_Codex_App_orchestration', 'Risk_overengineering')) {
    if ($multiPerspectiveReview -notmatch "(?m)^\s*$([regex]::Escape($view)):\s*$") {
      Add-Issue -Level 'error' -Message "multi_perspective_review.yaml must include view: $view." -File '.workflow/templates/multi_perspective_review.yaml'
    }
  }
  foreach ($field in @('finding:', 'evidence:', 'risks_or_objections:', 'next_action:', 'does_not_prove:')) {
    if ($multiPerspectiveReview -notmatch [regex]::Escape($field)) {
      Add-Issue -Level 'error' -Message "multi_perspective_review.yaml must include $field." -File '.workflow/templates/multi_perspective_review.yaml'
    }
  }
}
if ($thread -and $thread -notmatch '(?m)^\s*main_thread:') {
  Add-Issue -Level 'warning' -Message 'thread_registry.yaml should include main_thread.' -File '.workflow/thread_registry.yaml'
}
if ($thread -and $thread -notmatch '(?m)^\s*lifecycle:\s*') {
  Add-Issue -Level 'warning' -Message 'thread_registry.yaml worker records should include lifecycle: one_shot | continuous.' -File '.workflow/thread_registry.yaml'
}
if ($memoryPoints -and ($memoryPoints -notmatch 'memory_points:' -or $memoryPoints -notmatch 'supersedes:')) {
  Add-Issue -Level 'warning' -Message 'memory_points.yaml should include memory_points and supersedes fields.' -File '.workflow/memory_points.yaml'
}
if ($modelPolicy -and ($modelPolicy -notmatch 'default_model_alias:\s*opus' -or $modelPolicy -notmatch 'cheap_model_alias:\s*sonnet')) {
  Add-Issue -Level 'warning' -Message 'model_policy.yaml should define opus as the default Claude review alias and sonnet as the quota-saving alias.' -File '.workflow/model_policy.yaml'
}
if ($modelPolicy -and ($modelPolicy -notmatch '(?m)^\s*route_discovery:\s*$' -or $modelPolicy -notmatch '(?m)^\s*profile_policy:\s*$')) {
  Add-Issue -Level 'warning' -Message 'model_policy.yaml should include route_discovery and profile_policy so Claude/cc2/Maestro routes are discovered and smoke-tested instead of hardcoded.' -File '.workflow/model_policy.yaml'
}
if ($multiModelPacket -and $multiModelPacket -notmatch 'requested_model_alias:\s*opus') {
  Add-Issue -Level 'warning' -Message 'multi_model_context_packet.md should include requested_model_alias: opus by default.' -File '.workflow/templates/multi_model_context_packet.md'
}
if ($modelReviewReceipt -and ($modelReviewReceipt -notmatch 'requested_model_alias:' -or $modelReviewReceipt -notmatch 'actual_model_verified_from_output:')) {
  Add-Issue -Level 'warning' -Message 'model_review_receipt.yaml should record requested model alias and whether the actual model was verified from output.' -File '.workflow/templates/model_review_receipt.yaml'
}

$combined = "$task`n$verification"
$claimsUiAccepted = $combined -match '(?i)(UI|UX)[^\r\n]*(status|accepted):\s*(accepted|done)|accepted[^\r\n]*(UI|UX)'
$hasVisibleEvidence = $combined -match '(?i)screenshot|browser|visual|browser_or_visual_evidence'
if ($claimsUiAccepted -and -not $hasVisibleEvidence) {
  Add-Issue -Level 'error' -Message 'UI/UX acceptance appears claimed without visible evidence.' -File '.workflow/verification.yaml'
}

$claimsImageAccepted = $combined -match '(?i)(generated image|image_quality)[^\r\n]*(status|accepted):\s*(accepted|done)|accepted[^\r\n]*(generated image|image_quality)'
$hasImageGate = $combined -match '(?i)generated_file|image_quality_review|human_gate|user_feedback|screenshot'
if ($claimsImageAccepted -and -not $hasImageGate) {
  Add-Issue -Level 'error' -Message 'Generated image acceptance appears claimed without visual/user gate evidence.' -File '.workflow/verification.yaml'
}

$claimsSampleAccepted = $combined -match '(?i)(sample|reference|source|ozon|seller-ready|platform-pass)[^\r\n]*(accepted|done|ready|passed)'
$hasSampleGate = $combined -match '(?i)sample_decision|source_fact_boundary|reference_boundary|user_confirmation|human_gate|screenshot|url'
if ($claimsSampleAccepted -and -not $hasSampleGate) {
  Add-Issue -Level 'error' -Message 'Sample/source/seller-ready claim appears without sample decision or human-gate evidence.' -File '.workflow/verification.yaml'
}

$claimsExternalWrite = $combined -match '(?i)(published|exported|submitted|ordered|saved to platform|external write|seller-ready)'
$hasExplicitApproval = $combined -match '(?i)explicit approval|user_confirmation|human_gate[^\r\n]*(accepted|approved)|approved_by_user'
if ($claimsExternalWrite -and -not $hasExplicitApproval) {
  Add-Issue -Level 'error' -Message 'External write/export/seller-ready claim appears without explicit approval evidence.' -File '.workflow/verification.yaml'
}

if ($thread -and $thread -match '(?mi)^\s*receipt_status:\s*accepted\s*$' -and $thread -notmatch '(?mi)accepted_by_main_at:') {
  Add-Issue -Level 'warning' -Message 'A worker receipt is accepted but accepted_by_main_at is missing.' -File '.workflow/thread_registry.yaml'
}

if (Test-Path -LiteralPath $dispatchDir -PathType Container) {
  $dispatchFiles = Get-ChildItem -LiteralPath $dispatchDir -File -ErrorAction SilentlyContinue
  if ($dispatchFiles.Count -gt 0) {
    Add-Issue -Level 'warning' -Message '.workflow/dispatch contains runtime worker prompts; keep only intentional trace artifacts, not template test residue.' -File '.workflow/dispatch'
  }
}

$result = [ordered]@{
  project = $project
  valid = -not ($issues | Where-Object { $_.level -eq 'error' })
  readiness = if (($issues | Where-Object { $_.level -eq 'error' }).Count -gt 0) {
    'invalid'
  } elseif (($issues | Where-Object { $_.level -eq 'warning' }).Count -gt 0) {
    'static_or_incomplete'
  } else {
    'workflow_shape_ok'
  }
  issue_count = $issues.Count
  issues = $issues
}

if ($Json) {
  $result | ConvertTo-Json -Depth 8
} else {
  if ($result.valid) {
    Write-Output "Agents Init workflow validation passed: $project"
    Write-Output "Readiness: $($result.readiness)"
  } else {
    Write-Output "Agents Init workflow validation failed: $project"
    Write-Output "Readiness: $($result.readiness)"
  }
  foreach ($issue in $issues) {
    Write-Output "[$($issue.level)] $($issue.file) $($issue.message)"
  }
}

if (-not $result.valid) {
  exit 1
}
