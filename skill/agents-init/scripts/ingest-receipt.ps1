[CmdletBinding()]
param(
  [Parameter(Mandatory = $true)]
  [string]$ProjectPath,

  [Parameter(Mandatory = $true)]
  [string]$ReceiptPath,

  [switch]$Apply,

  [ValidateSet('accepted', 'rejected')]
  [string]$Decision = 'accepted',

  [switch]$Json
)

$ErrorActionPreference = 'Stop'

function Add-Issue {
  param(
    [Parameter(Mandatory = $true)][string]$Level,
    [Parameter(Mandatory = $true)][string]$Message
  )
  $script:issues += [ordered]@{
    level = $Level
    message = $Message
  }
}

function Test-FieldPresent {
  param([string]$Text, [string]$Field)
  return $Text -match "(?m)^\s*$([regex]::Escape($Field))\s*:"
}

function Test-FieldHasContent {
  param([string]$Text, [string]$Field)
  $inline = [regex]::Match($Text, "(?m)^\s*$([regex]::Escape($Field))\s*:\s*(.+?)\s*$")
  if ($inline.Success) {
    $value = $inline.Groups[1].Value.Trim()
    if ($value -and $value -notin @('[]', '{}', 'null', '""', "''")) {
      return $true
    }
  }

  $block = [regex]::Match($Text, "(?ms)^\s*$([regex]::Escape($Field))\s*:\s*\r?\n(?<body>(?:\s+-\s+\S.*\r?\n?)+)")
  return $block.Success
}

function Get-ScalarField {
  param([string]$Text, [string]$Field)
  $match = [regex]::Match($Text, "(?m)^\s*$([regex]::Escape($Field))\s*:\s*(.+?)\s*$")
  if (-not $match.Success) {
    return ''
  }
  $value = $match.Groups[1].Value.Trim()
  if ($value -in @('[]', '{}', 'null')) {
    return ''
  }
  return $value.Trim('"').Trim("'")
}

function Get-ListField {
  param([string]$Text, [string]$Field)
  $items = @()
  $pattern = "(?ms)^\s*$([regex]::Escape($Field))\s*:\s*\r?\n(?<body>(?:\s+-\s+.*(?:\r?\n|$))*)"
  $match = [regex]::Match($Text, $pattern)
  if ($match.Success) {
    foreach ($line in ($match.Groups['body'].Value -split "\r?\n")) {
      if ($line -match '^\s*-\s*(.+?)\s*$') {
        $item = $Matches[1].Trim()
        if ($item -and $item -notin @('""', "''")) {
          $items += $item.Trim('"').Trim("'")
        }
      }
    }
  }

  if ($items.Count -eq 0) {
    $scalar = Get-ScalarField -Text $Text -Field $Field
    if ($scalar -and $scalar -notin @('[]', '{}')) {
      $items += $scalar
    }
  }

  return @($items)
}

function Format-YamlString {
  param([string]$Value)
  if ([string]::IsNullOrWhiteSpace($Value)) {
    return '""'
  }
  return '"' + ($Value -replace '\\', '\\' -replace '"', '\"') + '"'
}

function Format-YamlList {
  param([string[]]$Items, [string]$Indent = '  ')
  $realItems = @($Items | Where-Object { -not [string]::IsNullOrWhiteSpace($_) })
  if ($realItems.Count -eq 0) {
    return "$Indent- " + '""'
  }
  return (($realItems | ForEach-Object { "$Indent- " + (Format-YamlString $_) }) -join "`n")
}

function Get-RelativePath {
  param([string]$BasePath, [string]$TargetPath)
  try {
    $base = [System.IO.Path]::GetFullPath($BasePath).TrimEnd([System.IO.Path]::DirectorySeparatorChar, [System.IO.Path]::AltDirectorySeparatorChar) + [System.IO.Path]::DirectorySeparatorChar
    $target = [System.IO.Path]::GetFullPath($TargetPath)
    $baseUri = [Uri]::new($base)
    $targetUri = [Uri]::new($target)
    return [Uri]::UnescapeDataString($baseUri.MakeRelativeUri($targetUri).ToString()).Replace('/', [System.IO.Path]::DirectorySeparatorChar)
  } catch {
    return $TargetPath
  }
}

function Add-VerificationEntry {
  param(
    [string]$Project,
    [string]$ReceiptRelativePath,
    [string]$TaskId,
    [string]$DecisionValue,
    [string[]]$Proves,
    [string[]]$DoesNotProve,
    [string[]]$Risks,
    [string[]]$NextSteps
  )

  $verificationPath = Join-Path $Project '.workflow\verification.yaml'
  if (-not (Test-Path -LiteralPath $verificationPath -PathType Leaf)) {
    throw "Missing workflow verification file: $verificationPath"
  }

  $safeTaskId = if ($TaskId) { ($TaskId -replace '[^A-Za-z0-9_.-]', '_').Trim('_') } else { 'receipt' }
  $stamp = (Get-Date).ToString('yyyyMMddHHmmss')
  $entryId = "receipt_apply_${safeTaskId}_$stamp"
  $status = if ($DecisionValue -eq 'accepted') { 'receipt_accepted_by_main' } else { 'receipt_rejected_by_main' }

  $entry = @"
- id: $entryId
  task_id: $(Format-YamlString $TaskId)
  status: $status
  commands_run:
  - command: "ingest-receipt.ps1 -Apply -Decision $DecisionValue"
    exit_code: 0
    summary: "Applied receipt decision to workflow state."
  artifacts:
  - $(Format-YamlString $ReceiptRelativePath)
  proves:
$(Format-YamlList -Items $Proves -Indent '  ')
  does_not_prove:
$(Format-YamlList -Items $DoesNotProve -Indent '  ')
  risks:
$(Format-YamlList -Items $Risks -Indent '  ')
  next_verification:
$(Format-YamlList -Items $NextSteps -Indent '  ')
"@

  $current = Get-Content -Raw -Encoding UTF8 -LiteralPath $verificationPath
  if ($current -match '(?m)^verification_log:\s*\[\]\s*$') {
    $updated = [regex]::Replace($current, '(?m)^verification_log:\s*\[\]\s*$', "verification_log:`n$entry", 1)
  } elseif ($current -match "(?m)^template:") {
    $updated = [regex]::Replace($current, "(?m)^template:", "$entry`n`ntemplate:", 1)
  } else {
    $updated = $current.TrimEnd() + "`n`n" + $entry + "`n"
  }
  Set-Content -LiteralPath $verificationPath -Value $updated -Encoding UTF8
  return $entryId
}

function Set-WorkerRecordField {
  param([string[]]$Lines, [int]$StartIndex, [int]$EndIndex, [string]$Field, [string]$Value)
  $fieldPattern = "^\s*$([regex]::Escape($Field))\s*:"
  for ($i = $StartIndex + 1; $i -le $EndIndex; $i++) {
    if ($Lines[$i] -match $fieldPattern) {
      $indent = ([regex]::Match($Lines[$i], '^\s*')).Value
      $Lines[$i] = "$indent${Field}: $Value"
      return ,$Lines
    }
  }

  $insertAt = $EndIndex + 1
  $newLine = "  ${Field}: $Value"
  if ($insertAt -ge $Lines.Count) {
    return ,(@($Lines) + $newLine)
  }
  return ,(@($Lines[0..$EndIndex]) + $newLine + @($Lines[($EndIndex + 1)..($Lines.Count - 1)]))
}

function Update-ThreadRegistry {
  param(
    [string]$Project,
    [string]$ActorId,
    [string]$ReceiptRelativePath,
    [string]$DecisionValue
  )

  if ([string]::IsNullOrWhiteSpace($ActorId)) {
    return $false
  }

  $registryPath = Join-Path $Project '.workflow\thread_registry.yaml'
  if (-not (Test-Path -LiteralPath $registryPath -PathType Leaf)) {
    return $false
  }

  $lines = @(Get-Content -Encoding UTF8 -LiteralPath $registryPath)
  $start = -1
  for ($i = 0; $i -lt $lines.Count; $i++) {
    if ($lines[$i] -match "^\s*-\s+id:\s*['""]?$([regex]::Escape($ActorId))['""]?\s*$") {
      $start = $i
      break
    }
  }
  if ($start -lt 0) {
    return $false
  }

  $end = $lines.Count - 1
  for ($i = $start + 1; $i -lt $lines.Count; $i++) {
    if ($lines[$i] -match '^\s*-\s+id:\s*' -or $lines[$i] -match '^[A-Za-z_][A-Za-z0-9_]*:\s*') {
      $end = $i - 1
      break
    }
  }

  $statusValue = if ($DecisionValue -eq 'accepted') { 'receipt_accepted' } else { 'receipt_rejected' }
  $receiptStatusValue = if ($DecisionValue -eq 'accepted') { 'accepted_by_main' } else { 'rejected_by_main' }
  $timestamp = '"' + (Get-Date).ToString('yyyy-MM-ddTHH:mm:ssK') + '"'

  $lines = @(Set-WorkerRecordField -Lines $lines -StartIndex $start -EndIndex $end -Field 'status' -Value $statusValue)
  $lines = @(Set-WorkerRecordField -Lines $lines -StartIndex $start -EndIndex ($lines.Count - 1) -Field 'receipt_status' -Value $receiptStatusValue)
  $lines = @(Set-WorkerRecordField -Lines $lines -StartIndex $start -EndIndex ($lines.Count - 1) -Field 'receipt_path' -Value (Format-YamlString $ReceiptRelativePath))
  $lines = @(Set-WorkerRecordField -Lines $lines -StartIndex $start -EndIndex ($lines.Count - 1) -Field 'accepted_by_main_at' -Value $timestamp)

  Set-Content -LiteralPath $registryPath -Value $lines -Encoding UTF8
  return $true
}

if (-not (Test-Path -LiteralPath $ProjectPath -PathType Container)) {
  throw "ProjectPath does not exist or is not a directory: $ProjectPath"
}
if (-not (Test-Path -LiteralPath $ReceiptPath -PathType Leaf)) {
  throw "ReceiptPath does not exist or is not a file: $ReceiptPath"
}

$project = (Resolve-Path -LiteralPath $ProjectPath).Path
$receiptFull = (Resolve-Path -LiteralPath $ReceiptPath).Path
$text = Get-Content -Raw -Encoding UTF8 -LiteralPath $receiptFull
$issues = @()

$requiredFields = @(
  'task_id',
  'status',
  'scope',
  'files_read',
  'files_changed',
  'commands_run',
  'evidence',
  'proves',
  'does_not_prove',
  'risks',
  'open_threads',
  'next_recommended_step'
)

foreach ($field in $requiredFields) {
  if (-not (Test-FieldPresent -Text $text -Field $field)) {
    Add-Issue -Level 'error' -Message "Missing required receipt field: $field"
  }
}

if ($text -match '(?mi)^\s*receipt_status:\s*accepted\s*$') {
  Add-Issue -Level 'warning' -Message 'Worker receipt claims accepted. Only the main agent can accept a receipt.'
}
if (-not (Test-FieldHasContent -Text $text -Field 'does_not_prove')) {
  Add-Issue -Level 'error' -Message 'does_not_prove is empty or missing; receipt cannot prove its limits.'
}
if (-not (Test-FieldHasContent -Text $text -Field 'evidence')) {
  Add-Issue -Level 'warning' -Message 'evidence appears empty; main agent should request evidence or mark receipt incomplete.'
}
if ($text -match '(?mi)^\s*files_changed:\s*(\r?\n\s*-\s+\S+|\S+)' -and $text -notmatch '(?mi)^\s*commands_run:\s*(\r?\n\s*-\s+\S+|\S+)') {
  Add-Issue -Level 'warning' -Message 'Receipt changed files but lists no commands; verification may be incomplete.'
}
if ($text -match '(?i)(accepted|done).*(UI|UX|image|sample)' -and $text -notmatch '(?i)(screenshot|visual|user|human_gate|sample_decision|image_quality_review)') {
  Add-Issue -Level 'error' -Message 'Receipt appears to claim UI/image/sample acceptance without visible or human-gate evidence.'
}

$hasErrors = ($issues | Where-Object { $_.level -eq 'error' }).Count -gt 0
$recommendation = if ($hasErrors) {
  'reject_or_request_revision'
} elseif (($issues | Where-Object { $_.level -eq 'warning' }).Count -gt 0) {
  'main_agent_review_required'
} else {
  'eligible_for_main_agent_acceptance'
}

$applied = $false
$applyUpdates = @()
if ($Apply) {
  if ($hasErrors) {
    Add-Issue -Level 'error' -Message 'Cannot apply a receipt with validation errors.'
    $hasErrors = $true
    $recommendation = 'reject_or_request_revision'
  } else {
    $taskId = Get-ScalarField -Text $text -Field 'task_id'
    $actorId = Get-ScalarField -Text $text -Field 'worker_thread_id'
    if ([string]::IsNullOrWhiteSpace($actorId)) {
      $actorId = Get-ScalarField -Text $text -Field 'worker_id'
    }
    if ([string]::IsNullOrWhiteSpace($actorId)) {
      $actorId = Get-ScalarField -Text $text -Field 'delegate_exec_id'
    }
    if ([string]::IsNullOrWhiteSpace($actorId)) {
      $actorId = Get-ScalarField -Text $text -Field 'model_session_id'
    }

    $receiptRelativePath = Get-RelativePath -BasePath $project -TargetPath $receiptFull
    $verificationId = Add-VerificationEntry `
      -Project $project `
      -ReceiptRelativePath $receiptRelativePath `
      -TaskId $taskId `
      -DecisionValue $Decision `
      -Proves (Get-ListField -Text $text -Field 'proves') `
      -DoesNotProve (Get-ListField -Text $text -Field 'does_not_prove') `
      -Risks (Get-ListField -Text $text -Field 'risks') `
      -NextSteps (Get-ListField -Text $text -Field 'next_recommended_step')

    $applyUpdates += "verification:$verificationId"
    if (Update-ThreadRegistry -Project $project -ActorId $actorId -ReceiptRelativePath $receiptRelativePath -DecisionValue $Decision) {
      $applyUpdates += "thread_registry:$actorId"
    } elseif ($actorId) {
      $applyUpdates += "thread_registry:no_matching_record:$actorId"
    } else {
      $applyUpdates += 'thread_registry:no_actor_id'
    }
    $applied = $true
  }
}

$result = [ordered]@{
  project = $project
  receipt = $receiptFull
  valid_shape = -not $hasErrors
  recommendation = $recommendation
  applied = $applied
  decision = if ($Apply) { $Decision } else { '' }
  apply_updates = $applyUpdates
  note = if ($Apply) { 'This script applied a main-agent receipt decision to workflow state. The main agent remains responsible for product/UI/sample/human-gated acceptance.' } else { 'This script checks receipt shape only. The main agent must inspect artifacts and decide acceptance.' }
  issues = $issues
}

if ($Json) {
  $result | ConvertTo-Json -Depth 6
  if ($hasErrors) {
    exit 1
  }
  exit 0
}

Write-Output "Agents Init Receipt Ingest Check"
Write-Output "Receipt: $receiptFull"
Write-Output "Recommendation: $recommendation"
foreach ($issue in $issues) {
  Write-Output "[$($issue.level)] $($issue.message)"
}

if ($hasErrors) {
  exit 1
}
