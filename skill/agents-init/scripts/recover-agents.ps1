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

function Get-FirstMatch {
  param(
    [Parameter(Mandatory = $true)][string]$Text,
    [Parameter(Mandatory = $true)][string]$Pattern,
    [string]$Default = ''
  )
  $m = [regex]::Match($Text, $Pattern, [System.Text.RegularExpressions.RegexOptions]::Multiline)
  if ($m.Success) {
    return $m.Groups[1].Value.Trim().Trim('"')
  }
  return $Default
}

function Get-ActiveTaskSummary {
  param([string]$Text)
  $inline = Get-FirstMatch $Text '(?m)^\s*active_task:\s*(.+)$' ''
  if ($inline -and $inline -notin @('null', '[]', '{}', '""', "''")) {
    return $inline
  }
  $id = Get-FirstMatch $Text '(?ms)^\s*active_task:\s*\r?\n(?:\s+[^\r\n]*\r?\n)*?\s+id:\s*(.+)$' ''
  $title = Get-FirstMatch $Text '(?ms)^\s*active_task:\s*\r?\n(?:\s+[^\r\n]*\r?\n)*?\s+title:\s*(.+)$' ''
  $status = Get-FirstMatch $Text '(?ms)^\s*active_task:\s*\r?\n(?:\s+[^\r\n]*\r?\n)*?\s+status:\s*(.+)$' ''
  $parts = @()
  if ($id) { $parts += "id=$id" }
  if ($title) { $parts += "title=$title" }
  if ($status) { $parts += "status=$status" }
  if ($parts.Count -gt 0) {
    return ($parts -join '; ')
  }
  return '<unknown>'
}

function Get-ListItemSummaries {
  param(
    [string]$Text,
    [int]$Limit = 5
  )

  $items = New-Object System.Collections.Generic.List[string]
  $lines = $Text -split "\r?\n"
  for ($i = 0; $i -lt $lines.Count; $i++) {
    if ($lines[$i] -match '^\s*-\s+id:\s*(.+)\s*$') {
      $id = $Matches[1].Trim()
      $summaryParts = New-Object System.Collections.Generic.List[string]
      $summaryParts.Add("id=$id")
      for ($j = $i + 1; $j -lt [Math]::Min($lines.Count, $i + 14); $j++) {
        if ($lines[$j] -match '^\s*-\s+id:') { break }
        if ($lines[$j] -match '^\s*(question|status|gate|next|task_id|proves|does_not_prove):\s*(.+)\s*$') {
          $summaryParts.Add("$($Matches[1])=$($Matches[2].Trim())")
        }
      }
      $items.Add(($summaryParts -join '; '))
      if ($items.Count -ge $Limit) { break }
    }
  }
  return @($items)
}

function Test-PlaceholderText {
  param([string]$Text)
  return $Text -match '<[^>\r\n]+>' -or $Text -match '(?m)^\s*(active_task|mission|next_action):\s*(null|""|''''|\s*)$'
}

function Test-RecoveredCoreIncomplete {
  param(
    [string]$Goal,
    [string]$Gate,
    [string]$ActiveTask,
    [string]$NextAction
  )
  foreach ($value in @($Goal, $Gate, $ActiveTask, $NextAction)) {
    if ([string]::IsNullOrWhiteSpace($value)) { return $true }
    if ($value -in @('<unknown>', 'null', '[]', '{}', '""', "''")) { return $true }
    if ($value -match '<[^>\r\n]+>') { return $true }
  }
  return $false
}

if (-not (Test-Path -LiteralPath $ProjectPath -PathType Container)) {
  throw "ProjectPath does not exist or is not a directory: $ProjectPath"
}

$project = (Resolve-Path -LiteralPath $ProjectPath).Path
$workflow = Join-Path $project '.workflow'

$paths = [ordered]@{
  current = Join-Path $workflow 'current.yaml'
  agents_init = Join-Path $workflow 'agents-init.yaml'
  task = Join-Path $workflow 'task.yaml'
  open_threads = Join-Path $workflow 'open_threads.yaml'
  verification = Join-Path $workflow 'verification.yaml'
  thread_registry = Join-Path $workflow 'thread_registry.yaml'
  memory_points = Join-Path $workflow 'memory_points.yaml'
}

$currentText = Read-TextOrEmpty $paths.current
$taskText = Read-TextOrEmpty $paths.task
$openText = Read-TextOrEmpty $paths.open_threads
$verificationText = Read-TextOrEmpty $paths.verification
$threadText = Read-TextOrEmpty $paths.thread_registry
$memoryText = Read-TextOrEmpty $paths.memory_points

$missing = @()
foreach ($key in $paths.Keys) {
  if (-not (Test-Path -LiteralPath $paths[$key] -PathType Leaf)) {
    $missing += $paths[$key]
  }
}

$recoveredGoal = Get-FirstMatch $currentText '(?m)^\s*mission:\s*(.+)$' '<unknown>'
$currentGate = Get-FirstMatch $currentText '(?m)^\s*current_gate:\s*(.+)$' '<unknown>'
$activeTaskSummary = Get-ActiveTaskSummary $taskText
$nextAction = Get-FirstMatch $currentText '(?m)^\s*next_action:\s*(.+)$' '<unknown>'

$summary = [ordered]@{
  project = $project
  workflow_present = Test-Path -LiteralPath $workflow -PathType Container
  missing_files = $missing
  recovered_goal = $recoveredGoal
  status = Get-FirstMatch $currentText '(?m)^\s*status:\s*(.+)$' '<unknown>'
  current_gate = $currentGate
  active_task = $activeTaskSummary
  next_action = $nextAction
  main_thread_id = Get-FirstMatch $threadText '(?m)^\s*id:\s*(.+)$' '<unknown>'
  readiness = if ($missing.Count -gt 0) {
    'missing_workflow_files'
  } elseif (Test-RecoveredCoreIncomplete -Goal $recoveredGoal -Gate $currentGate -ActiveTask $activeTaskSummary -NextAction $nextAction) {
    'placeholder_or_no_active_task'
  } else {
    'recoverable'
  }
  open_threads_summary = @(Get-ListItemSummaries -Text $openText -Limit 7)
  verification_summary = @(Get-ListItemSummaries -Text $verificationText -Limit 7)
  worker_summary = @(Get-ListItemSummaries -Text $threadText -Limit 7)
  memory_points_summary = @(Get-ListItemSummaries -Text $memoryText -Limit 7)
  counts = [ordered]@{
    open_thread_markers = ([regex]::Matches($openText, '(?m)^\s*-\s+id:')).Count
    verification_entries = ([regex]::Matches($verificationText, '(?m)^\s*-\s+id:')).Count
    worker_records = ([regex]::Matches($threadText, '(?m)^\s*-\s+id:')).Count
    memory_points = ([regex]::Matches($memoryText, '(?m)^\s*-\s+id:')).Count
  }
  forbidden_claims = [ordered]@{
    ui_without_visible_evidence = ($taskText + $verificationText) -match '(?i)(UI|UX)[^\r\n]*(status|accepted):\s*(accepted|done)|accepted[^\r\n]*(UI|UX)' -and $verificationText -notmatch '(?i)screenshot|browser|visual'
    generated_image_without_user_gate = ($taskText + $verificationText) -match '(?i)(generated image|image_quality)[^\r\n]*(status|accepted):\s*(accepted|done)|accepted[^\r\n]*(generated image|image_quality)' -and $verificationText -notmatch '(?i)user|human_gate|screenshot|generated_file'
  }
  read_first = @(
    '.workflow/current.yaml',
    '.workflow/agents-init.yaml',
    '.workflow/task.yaml',
    '.workflow/open_threads.yaml',
    '.workflow/verification.yaml',
    '.workflow/thread_registry.yaml',
    '.workflow/memory_points.yaml'
  )
}

if ($Json) {
  $summary | ConvertTo-Json -Depth 8
  exit 0
}

Write-Output "Agents Init Recovery"
Write-Output "Project: $($summary.project)"
Write-Output "Status: $($summary.status)"
Write-Output "Readiness: $($summary.readiness)"
Write-Output "Goal: $($summary.recovered_goal)"
Write-Output "Gate: $($summary.current_gate)"
Write-Output "Active task: $($summary.active_task)"
Write-Output "Main thread: $($summary.main_thread_id)"
Write-Output "Open thread markers: $($summary.counts.open_thread_markers)"
Write-Output "Memory points: $($summary.counts.memory_points)"
Write-Output "Verification entries: $($summary.counts.verification_entries)"
Write-Output "Next action: $($summary.next_action)"

if ($summary.open_threads_summary.Count -gt 0) {
  Write-Output ""
  Write-Output "Open threads:"
  $summary.open_threads_summary | ForEach-Object { Write-Output "- $_" }
}

if ($summary.verification_summary.Count -gt 0) {
  Write-Output ""
  Write-Output "Verification:"
  $summary.verification_summary | ForEach-Object { Write-Output "- $_" }
}

if ($summary.memory_points_summary.Count -gt 0) {
  Write-Output ""
  Write-Output "Memory points:"
  $summary.memory_points_summary | ForEach-Object { Write-Output "- $_" }
}

if ($summary.worker_summary.Count -gt 0) {
  Write-Output ""
  Write-Output "Workers/delegates:"
  $summary.worker_summary | ForEach-Object { Write-Output "- $_" }
}

if ($missing.Count -gt 0) {
  Write-Output ""
  Write-Output "Missing files:"
  $missing | ForEach-Object { Write-Output "- $_" }
}

if ($summary.forbidden_claims.ui_without_visible_evidence -or $summary.forbidden_claims.generated_image_without_user_gate) {
  Write-Output ""
  Write-Output "Risk flags:"
  if ($summary.forbidden_claims.ui_without_visible_evidence) {
    Write-Output "- UI acceptance appears claimed without visible evidence."
  }
  if ($summary.forbidden_claims.generated_image_without_user_gate) {
    Write-Output "- Generated image acceptance appears claimed without user/visual gate."
  }
}
