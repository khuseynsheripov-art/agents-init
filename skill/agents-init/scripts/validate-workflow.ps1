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

function Test-SuspiciousYamlDoubleQuote {
  param([string]$Text)
  if (-not $Text) {
    return $false
  }
  return $Text -match '(?m):\s*"[^"\r\n]*""'
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

function Test-TextFileEncoding {
  param(
    [Parameter(Mandatory = $true)][string]$Path,
    [Parameter(Mandatory = $true)][string]$Relative
  )
  if (-not (Test-Path -LiteralPath $Path -PathType Leaf)) {
    return
  }

  $bytes = [System.IO.File]::ReadAllBytes($Path)
  if ($bytes.Length -ge 3 -and $bytes[0] -eq 0xEF -and $bytes[1] -eq 0xBB -and $bytes[2] -eq 0xBF) {
    Add-Issue -Level 'warning' -Message "$Relative has UTF-8 BOM; normalize to BOM-less UTF-8 for stricter parsers and byte-level tests." -File $Relative
  }
  if ($bytes.Length -ge 2 -and (($bytes[0] -eq 0xFF -and $bytes[1] -eq 0xFE) -or ($bytes[0] -eq 0xFE -and $bytes[1] -eq 0xFF))) {
    Add-Issue -Level 'warning' -Message "$Relative appears to use UTF-16 BOM; normalize workflow text files to UTF-8." -File $Relative
  }
  if ($bytes -contains 0) {
    Add-Issue -Level 'warning' -Message "$Relative contains NUL bytes; workflow text files should be plain UTF-8 text." -File $Relative
  }

  try {
    $strictUtf8 = [System.Text.UTF8Encoding]::new($false, $true)
    $text = $strictUtf8.GetString($bytes)
  } catch {
    Add-Issue -Level 'error' -Message "$Relative is not valid UTF-8." -File $Relative
    return
  }

  $crlfCount = [regex]::Matches($text, "\r\n").Count
  $lfOnlyCount = [regex]::Matches($text, "(?<!\r)\n").Count
  if ($crlfCount -gt 0 -and $lfOnlyCount -gt 0) {
    Add-Issue -Level 'warning' -Message "$Relative has mixed line endings (CRLF=$crlfCount, LF-only=$lfOnlyCount); normalize before using strict diff or YAML tooling." -File $Relative
  }

  $badInvisible = [char[]]@([char]0x200B, [char]0x200C, [char]0x200D, [char]0xFEFF, [char]0x202A, [char]0x202B, [char]0x202C, [char]0x202D, [char]0x202E, [char]0x00A0, [char]0x00AD)
  foreach ($ch in $badInvisible) {
    if ($text.IndexOf($ch) -ge 0) {
      Add-Issue -Level 'warning' -Message ("$Relative contains invisible or control character U+{0:X4}." -f [int][char]$ch) -File $Relative
      break
    }
  }
}

function Test-WorkflowTextFile {
  param([Parameter(Mandatory = $true)][System.IO.FileInfo]$File)
  $textExtensions = @(
    '.yaml',
    '.yml',
    '.md',
    '.txt',
    '.json',
    '.jsonl',
    '.ps1',
    '.py',
    '.js',
    '.ts',
    '.tsx',
    '.css',
    '.html'
  )
  return $textExtensions -contains $File.Extension.ToLowerInvariant()
}

function Remove-NegativeEvidenceBlocks {
  param([string]$Text)
  if (-not $Text) {
    return ''
  }
  $withoutDoesNotProve = [regex]::Replace($Text, '(?ms)^\s*does_not_prove:\s*\r?\n(?:^\s+- .*\r?\n?)*', '')
  $withoutRisks = [regex]::Replace($withoutDoesNotProve, '(?ms)^\s*risks:\s*\r?\n(?:^\s+- .*\r?\n?)*', '')
  return [regex]::Replace($withoutRisks, '(?ms)^\s*next_verification:\s*\r?\n(?:^\s+- .*\r?\n?)*', '')
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

function Get-TopLevelListBlocks {
  param([string]$Text)
  if (-not $Text) {
    return @()
  }
  $blocks = New-Object System.Collections.Generic.List[string]
  foreach ($match in [regex]::Matches($Text, '(?ms)^-\s+\S.*?(?=^-\s+\S|\z)')) {
    $blocks.Add($match.Value)
  }
  return @($blocks)
}

function Get-YamlBlock {
  param(
    [string]$Text,
    [string]$Key
  )
  if (-not $Text) {
    return ''
  }
  $match = [regex]::Match($Text, "(?ms)^\s*$([regex]::Escape($Key)):\s*\r?\n(?<block>(?:^\s+.*\r?\n?)*)")
  if ($match.Success) {
    return $match.Groups['block'].Value
  }
  return ''
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
  '.workflow/authority_index.yaml',
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
  '.workflow/templates/design_debate_receipt.yaml',
  '.workflow/templates/document_lifecycle_receipt.yaml',
  '.workflow/templates/plan_pm_fde.yaml',
  '.workflow/templates/session_recovery_brief.md',
  '.workflow/templates/workflow_closeout_receipt.yaml',
  'docs/dev-os/command-intent-map.md',
  'docs/dev-os/multi-codex-session-mode.md'
)

foreach ($relative in $requiredFiles) {
  $path = Join-Path $project $relative
  if (-not (Test-Path -LiteralPath $path -PathType Leaf)) {
    Add-Issue -Level 'error' -Message "Missing required workflow file: $relative" -File $relative
  }
}

if (Test-Path -LiteralPath $workflow -PathType Container) {
  $workflowTextFiles = Get-ChildItem -LiteralPath $workflow -Recurse -File -ErrorAction SilentlyContinue | Where-Object {
    Test-WorkflowTextFile -File $_
  }
  foreach ($file in $workflowTextFiles) {
    $relative = $file.FullName.Substring($project.Length).TrimStart('\') -replace '\\', '/'
    Test-TextFileEncoding -Path $file.FullName -Relative $relative
  }
}

$currentPath = Join-Path $project '.workflow/current.yaml'
$taskPath = Join-Path $project '.workflow/task.yaml'
$verificationPath = Join-Path $project '.workflow/verification.yaml'
$threadPath = Join-Path $project '.workflow/thread_registry.yaml'
$memoryPointsPath = Join-Path $project '.workflow/memory_points.yaml'
$modelPolicyPath = Join-Path $project '.workflow/model_policy.yaml'
$authorityIndexPath = Join-Path $project '.workflow/authority_index.yaml'
$sessionRecoveryPath = Join-Path $project '.workflow/session-recovery-brief.md'
$workerReceiptPath = Join-Path $project '.workflow/templates/worker_receipt.yaml'
$orchestrationDecisionPath = Join-Path $project '.workflow/templates/orchestration_decision.yaml'
$multiPerspectiveReviewPath = Join-Path $project '.workflow/templates/multi_perspective_review.yaml'
$multiModelPacketPath = Join-Path $project '.workflow/templates/multi_model_context_packet.md'
$modelReviewReceiptPath = Join-Path $project '.workflow/templates/model_review_receipt.yaml'
$designDebateReceiptPath = Join-Path $project '.workflow/templates/design_debate_receipt.yaml'
$workflowCloseoutReceiptPath = Join-Path $project '.workflow/templates/workflow_closeout_receipt.yaml'
$dispatchDir = Join-Path $project '.workflow/dispatch'

$current = Read-TextOrEmpty $currentPath
$task = Read-TextOrEmpty $taskPath
$verification = Read-TextOrEmpty $verificationPath
$thread = Read-TextOrEmpty $threadPath
$memoryPoints = Read-TextOrEmpty $memoryPointsPath
$modelPolicy = Read-TextOrEmpty $modelPolicyPath
$authorityIndex = Read-TextOrEmpty $authorityIndexPath
$sessionRecovery = Read-TextOrEmpty $sessionRecoveryPath
$workerReceipt = Read-TextOrEmpty $workerReceiptPath
$orchestrationDecision = Read-TextOrEmpty $orchestrationDecisionPath
$multiPerspectiveReview = Read-TextOrEmpty $multiPerspectiveReviewPath
$multiModelPacket = Read-TextOrEmpty $multiModelPacketPath
$modelReviewReceipt = Read-TextOrEmpty $modelReviewReceiptPath
$designDebateReceipt = Read-TextOrEmpty $designDebateReceiptPath
$workflowCloseoutReceipt = Read-TextOrEmpty $workflowCloseoutReceiptPath

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
if ($orchestrationDecision -and ($orchestrationDecision -match '(?m)^\s*summary_only_failure:\s*true\s*$' -or $orchestrationDecision -match '(?ms)^\s*product_system_fit_gate:\s*\r?\n(?:(?!^[^\s]).*\r?\n)*?\s+required:\s*true\s*$')) {
  foreach ($field in @('original_product_anchors:', 'native_interaction_grammar:', 'capability_reuse_plan:', 'candidate_insertion_points:', 'integration_fit:', 'first_visible_slice_acceptance:', 'design_debate_receipt:')) {
    if ($orchestrationDecision -notmatch [regex]::Escape($field)) {
      Add-Issue -Level 'warning' -Message "Product-System Fit Gate is required or summary_only_failure is true, but orchestration_decision.yaml is missing $field." -File '.workflow/templates/orchestration_decision.yaml'
    }
  }
  if ($orchestrationDecision -notmatch '(?m)^\s*evidence_bound_product_fit:\s*$') {
    Add-Issue -Level 'warning' -Message 'Product-System Fit Gate requires evidence_bound_product_fit before treating a correct-direction summary as sufficient.' -File '.workflow/templates/orchestration_decision.yaml'
  }
}
$integrationFit = Get-YamlBlock -Text $orchestrationDecision -Key 'integration_fit'
if ($integrationFit) {
  $targetSurface = [regex]::Match($integrationFit, '(?m)^\s*target_surface_level:\s*(?<value>\S+)')
  $fitStatus = [regex]::Match($integrationFit, '(?m)^\s*status:\s*(?<value>\S+)')
  $editorProof = [regex]::Match($integrationFit, '(?m)^\s*editor_internal_integration_proven_by:\s*(?<value>.+?)\s*$')
  $firstSlice = [regex]::Match($integrationFit, '(?ms)^\s*first_slice_must_show:\s*\r?\n\s*-\s*(?<value>.+?)\s*$')
  $proofValue = if ($editorProof.Success) { $editorProof.Groups['value'].Value.Trim().Trim('"').Trim("'") } else { '' }
  $firstSliceValue = if ($firstSlice.Success) { $firstSlice.Groups['value'].Value.Trim().Trim('"').Trim("'") } else { '' }
  if ($fitStatus.Success -and $fitStatus.Groups['value'].Value -eq 'passed' -and $targetSurface.Success -and $targetSurface.Groups['value'].Value -match '^(global_nav|first_level_workspace)$') {
    Add-Issue -Level 'warning' -Message 'integration_fit claims passed while target_surface_level is global_nav or first_level_workspace; placement/entry alone does not prove editor or workflow integration.' -File '.workflow/templates/orchestration_decision.yaml'
  }
  if ($fitStatus.Success -and $fitStatus.Groups['value'].Value -eq 'passed' -and ([string]::IsNullOrWhiteSpace($proofValue) -or $proofValue -match '^(<.*>|""|''''|null)$') -and ([string]::IsNullOrWhiteSpace($firstSliceValue) -or $firstSliceValue -match '^(<.*>|""|''''|null)$')) {
    Add-Issue -Level 'warning' -Message 'integration_fit claims passed without editor_internal_integration_proven_by or first_slice_must_show evidence.' -File '.workflow/templates/orchestration_decision.yaml'
  }
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
if ($authorityIndex -and ($authorityIndex -notmatch 'current_authority:' -or $authorityIndex -notmatch 'active_evidence:' -or $authorityIndex -notmatch 'superseded:' -or $authorityIndex -notmatch 'promoted:' -or $authorityIndex -notmatch 'archived:')) {
  Add-Issue -Level 'warning' -Message 'authority_index.yaml should include current_authority, active_evidence, superseded, promoted, and archived sections.' -File '.workflow/authority_index.yaml'
}
if ($authorityIndex -and (Test-LikelyMojibake $authorityIndex)) {
  Add-Issue -Level 'error' -Message 'authority_index.yaml appears to contain mojibake or corrupted non-ASCII text.' -File '.workflow/authority_index.yaml'
}
if ($workflowCloseoutReceipt) {
  foreach ($field in @('reason:', 'active_head_before:', 'active_head_after:', 'updated_heads:', 'authority_index_updates:', 'maestro_promotions:', 'session_recovery_update:', 'validation_status:', 'proves:', 'does_not_prove:')) {
    if ($workflowCloseoutReceipt -notmatch [regex]::Escape($field)) {
      Add-Issue -Level 'error' -Message "workflow_closeout_receipt.yaml must include $field." -File '.workflow/templates/workflow_closeout_receipt.yaml'
    }
  }
}
if ($sessionRecovery) {
  if (Test-LikelyMojibake $sessionRecovery) {
    Add-Issue -Level 'warning' -Message 'session-recovery brief appears to contain mojibake or corrupted non-ASCII text.' -File '.workflow/session-recovery-brief.md'
  }
  $gateMatch = [regex]::Match($current, '(?m)^\s*current_gate:\s*(?<value>.+?)\s*$')
  if ($gateMatch.Success) {
    $currentGate = $gateMatch.Groups['value'].Value.Trim().Trim('"').Trim("'")
    if ($currentGate -and $currentGate -notmatch '^(<.*>|null|""|'''')$' -and $sessionRecovery -notmatch [regex]::Escape($currentGate)) {
      Add-Issue -Level 'warning' -Message 'session-recovery brief appears stale: current_gate from current.yaml is not present.' -File '.workflow/session-recovery-brief.md'
    }
  }
  $activeTaskBlockForRecovery = Get-YamlBlock -Text $task -Key 'active_task'
  $activeTaskIdMatch = [regex]::Match($activeTaskBlockForRecovery, '(?m)^\s*id:\s*(?<value>[^\r\n#]+)')
  if ($activeTaskIdMatch.Success) {
    $activeTaskId = $activeTaskIdMatch.Groups['value'].Value.Trim().Trim('"').Trim("'")
    if ($activeTaskId -and $activeTaskId -notmatch '^(<.*>|null|""|'''')$' -and $sessionRecovery -notmatch [regex]::Escape($activeTaskId)) {
      Add-Issue -Level 'warning' -Message 'session-recovery brief appears stale: active_task from task.yaml is not present.' -File '.workflow/session-recovery-brief.md'
    }
  }
}
$activeTaskBlockForStaleness = Get-YamlBlock -Text $task -Key 'active_task'
$activeTaskUpdatedMatch = [regex]::Match($activeTaskBlockForStaleness, "(?m)^\s*updated_at:\s*['""]?(?<date>\d{4}-\d{2}-\d{2})")
if ($activeTaskUpdatedMatch.Success) {
  try {
    $activeTaskUpdated = [datetime]::ParseExact($activeTaskUpdatedMatch.Groups['date'].Value, 'yyyy-MM-dd', [Globalization.CultureInfo]::InvariantCulture)
    $latestVerificationDate = $null
    foreach ($dateMatch in [regex]::Matches($verification, "(?m)^\s*(recorded_at|finished_at|updated_at):\s*['""]?(?<date>\d{4}-\d{2}-\d{2})")) {
      try {
        $candidateDate = [datetime]::ParseExact($dateMatch.Groups['date'].Value, 'yyyy-MM-dd', [Globalization.CultureInfo]::InvariantCulture)
        if ($null -eq $latestVerificationDate -or $candidateDate -gt $latestVerificationDate) {
          $latestVerificationDate = $candidateDate
        }
      } catch {
      }
    }
    if ($null -ne $latestVerificationDate -and ($latestVerificationDate - $activeTaskUpdated).TotalDays -gt 7) {
      Add-Issue -Level 'warning' -Message 'task.yaml active_task appears older than latest verification evidence; close out, refresh, or supersede the task head.' -File '.workflow/task.yaml'
    }
  } catch {
    Add-Issue -Level 'warning' -Message 'task.yaml active_task has an unparsable updated_at date.' -File '.workflow/task.yaml'
  }
}
if ($modelPolicy -and ($modelPolicy -notmatch 'default_model_alias:\s*opus' -or $modelPolicy -notmatch 'cheap_model_alias:\s*sonnet')) {
  Add-Issue -Level 'warning' -Message 'model_policy.yaml should define opus as the default Claude review alias and sonnet as the quota-saving alias.' -File '.workflow/model_policy.yaml'
}
if ($modelPolicy -and ($modelPolicy -notmatch 'preferred_route:\s*maestro_delegate_when_raw_output_proven' -or $modelPolicy -notmatch 'fallback_route:\s*cc2_profile_reference_capturable_cli')) {
  Add-Issue -Level 'warning' -Message 'model_policy.yaml should prefer Maestro delegate when raw output is proven and treat cc2 as a profile/alias fallback, not the default lifecycle.' -File '.workflow/model_policy.yaml'
}
if ($modelPolicy -and $modelPolicy -notmatch '(?m)^\s*route_evidence:\s*$') {
  Add-Issue -Level 'warning' -Message 'model_policy.yaml should include route_evidence so Maestro/cc2 route status is separated from route policy.' -File '.workflow/model_policy.yaml'
}
if ($modelPolicy -and $modelPolicy -match '(?ms)^\s{2}maestro_delegate:\s*\r?\n(?:(?!^\s{2}\S).)*?^\s{4}status:\s*not_tested\s*$') {
  Add-Issue -Level 'warning' -Message 'Maestro delegate route policy is configured but raw-output smoke is not recorded as proven.' -File '.workflow/model_policy.yaml'
}
if ($modelPolicy -and $modelPolicy -match 'Prefer a project-approved wrapper such as cc2 when it smokes successfully') {
  Add-Issue -Level 'warning' -Message 'model_policy.yaml still contains the old cc2-first route policy; rerun agents-init upgrade.' -File '.workflow/model_policy.yaml'
}
if ($modelPolicy -and (Test-SuspiciousYamlDoubleQuote $modelPolicy)) {
  Add-Issue -Level 'error' -Message 'model_policy.yaml appears to contain YAML-invalid doubled quotes inside a double-quoted scalar; use backslash-escaped quotes or single quotes.' -File '.workflow/model_policy.yaml'
}
if ($modelPolicy -and (Test-LikelyMojibake $modelPolicy)) {
  Add-Issue -Level 'error' -Message 'model_policy.yaml appears to contain mojibake or corrupted non-ASCII text; replace the route policy block from the current template.' -File '.workflow/model_policy.yaml'
}
if ($modelPolicy -and $modelPolicy -match 'claude-opus-4\.7|4\.7-thinking|--model claude-opus-|claude\.exe') {
  Add-Issue -Level 'error' -Message 'model_policy.yaml contains stale/non-portable Claude route or concrete model text; use discovered commands and model alias opus/sonnet.' -File '.workflow/model_policy.yaml'
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
if ($designDebateReceipt) {
  foreach ($field in @('participants:', 'evidence_used:', 'hypotheses:', 'accepted_objections:', 'rejected_objections:', 'main_agent_synthesis:', 'does_not_prove:')) {
    if ($designDebateReceipt -notmatch [regex]::Escape($field)) {
      Add-Issue -Level 'warning' -Message "design_debate_receipt.yaml should include $field so model/worker debates remain inspectable." -File '.workflow/templates/design_debate_receipt.yaml'
    }
  }
}

$combined = "$task`n$verification"
$positiveCombined = Remove-NegativeEvidenceBlocks $combined
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

$claimsExternalWrite = $positiveCombined -match '(?i)(published|exported|submitted|ordered|saved to platform|external write|seller-ready)'
$hasExplicitApproval = $combined -match '(?i)explicit approval|user_confirmation|human_gate[^\r\n]*(accepted|approved)|approved_by_user'
if ($claimsExternalWrite -and -not $hasExplicitApproval) {
  Add-Issue -Level 'error' -Message 'External write/export/seller-ready claim appears without explicit approval evidence.' -File '.workflow/verification.yaml'
}

if ($thread -and $thread -match '(?mi)^\s*receipt_status:\s*accepted\s*$' -and $thread -notmatch '(?mi)accepted_by_main_at:') {
  Add-Issue -Level 'warning' -Message 'A worker receipt is accepted but accepted_by_main_at is missing.' -File '.workflow/thread_registry.yaml'
}
if ($thread) {
  foreach ($block in (Get-TopLevelListBlocks -Text $thread)) {
    if ($block -match '(?mi)^\s*status:\s*(no_output|interrupted|restarted)\s*$') {
      $idMatch = [regex]::Match($block, '(?mi)^\s*-\s+id:\s*(?<id>[^\r\n]+)|^\s*id:\s*(?<id>[^\r\n]+)')
      $recordId = if ($idMatch.Success) { $idMatch.Groups['id'].Value.Trim() } else { '<unknown>' }
      if ($block -notmatch '(?mi)^\s*close_reason:\s*(?!(""|''''|<|null\s*$))\S+') {
        Add-Issue -Level 'warning' -Message "Worker/delegate lifecycle record $recordId is no_output/interrupted/restarted without close_reason; started work must not count as evidence." -File '.workflow/thread_registry.yaml'
      }
      if ($block -notmatch '(?mi)^\s*next_action:\s*(?!(""|''''|<|null\s*$))\S+') {
        Add-Issue -Level 'warning' -Message "Worker/delegate lifecycle record $recordId is no_output/interrupted/restarted without next_action; recovery cannot tell what to do next." -File '.workflow/thread_registry.yaml'
      }
    }
  }
}

if (Test-Path -LiteralPath $verificationPath -PathType Leaf) {
  $verificationItem = Get-Item -LiteralPath $verificationPath
  $verificationLineCount = if ($verification) { ($verification -split "\r?\n").Count } else { 0 }
  if ($verificationItem.Length -gt 65536 -or $verificationLineCount -gt 1000) {
    Add-Issue -Level 'warning' -Message "verification.yaml is large ($verificationLineCount lines, $($verificationItem.Length) bytes); archive historical entries and keep only the active proof head." -File '.workflow/verification.yaml'
  }
}

if (Test-Path -LiteralPath (Join-Path $workflow 'open_threads.yaml') -PathType Leaf) {
  $openThreads = Read-TextOrEmpty (Join-Path $workflow 'open_threads.yaml')
  $threadBlocks = [regex]::Matches($openThreads, '(?ms)^- id:\s*(?<id>[^\r\n]+).*?(?=^- id:|\z)')
  $openCount = 0
  $closedCount = 0
  $staleOpen = @()
  $now = Get-Date
  foreach ($match in $threadBlocks) {
    $block = $match.Value
    if ($block -match '(?m)^\s*status:\s*open\s*$') {
      $openCount += 1
      $lastUpdated = [regex]::Match($block, "(?m)^\s*last_updated:\s*'?(?<date>\d{4}-\d{2}-\d{2})'?")
      if ($lastUpdated.Success) {
        try {
          $date = [datetime]::ParseExact($lastUpdated.Groups['date'].Value, 'yyyy-MM-dd', [Globalization.CultureInfo]::InvariantCulture)
          if (($now - $date).TotalDays -gt 14) {
            $staleOpen += $match.Groups['id'].Value.Trim()
          }
        } catch {
          Add-Issue -Level 'warning' -Message "open_threads.yaml has an unparsable last_updated date for open thread $($match.Groups['id'].Value.Trim())." -File '.workflow/open_threads.yaml'
        }
      } else {
        $staleOpen += $match.Groups['id'].Value.Trim()
      }
    } elseif ($block -match '(?m)^\s*status:\s*closed\s*$') {
      $closedCount += 1
    }
  }
  $totalThreadCount = $openCount + $closedCount
  if ($openCount -gt 6) {
    Add-Issue -Level 'warning' -Message "open_threads.yaml has many open threads ($openCount open); close, merge, or supersede stale questions before claiming healthy recovery." -File '.workflow/open_threads.yaml'
  }
  if ($totalThreadCount -gt 0) {
    $closureRate = [math]::Round(($closedCount / $totalThreadCount) * 100, 0)
    if ($totalThreadCount -ge 4 -and $closureRate -lt 30) {
      Add-Issue -Level 'warning' -Message "open_threads.yaml closure rate is low ($closureRate% closed across $totalThreadCount tracked threads); active recovery may be carrying unresolved decisions." -File '.workflow/open_threads.yaml'
    }
  }
  if ($staleOpen.Count -gt 0) {
    Add-Issue -Level 'warning' -Message "open_threads.yaml has stale open thread(s): $($staleOpen -join ', ')." -File '.workflow/open_threads.yaml'
  }
}

if (Test-Path -LiteralPath $workflow -PathType Container) {
  $flatReceipts = Get-ChildItem -LiteralPath $workflow -File -ErrorAction SilentlyContinue | Where-Object {
    $_.Name -match '^(worker|delegate|model-review|verification|handoff)-receipt.*\.(yaml|yml|md)$'
  }
  if ($flatReceipts.Count -gt 0) {
    Add-Issue -Level 'warning' -Message ".workflow root contains flat receipt file(s): $($flatReceipts.Name -join ', '); archive ingested receipts under .workflow/archive/receipts." -File '.workflow'
  }
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
