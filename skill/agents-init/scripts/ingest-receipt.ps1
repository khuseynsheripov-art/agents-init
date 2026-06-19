[CmdletBinding()]
param(
  [Parameter(Mandatory = $true)]
  [string]$ProjectPath,

  [Parameter(Mandatory = $true)]
  [string]$ReceiptPath,

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

$result = [ordered]@{
  project = $project
  receipt = $receiptFull
  valid_shape = -not $hasErrors
  recommendation = $recommendation
  note = 'This script checks receipt shape only. The main agent must inspect artifacts and decide acceptance.'
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
