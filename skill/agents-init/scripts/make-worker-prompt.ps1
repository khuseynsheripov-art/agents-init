[CmdletBinding()]
param(
  [Parameter(Mandatory = $true)]
  [string]$ProjectPath,

  [Parameter(Mandatory = $true)]
  [string]$TaskId,

  [Parameter(Mandatory = $true)]
  [string]$Task,

  [string]$Scope = '',
  [string[]]$MayRead = @(),
  [string[]]$MayEdit = @(),
  [string[]]$MustNotEdit = @('.workflow/current.yaml', '.workflow/task.yaml', '.workflow/open_threads.yaml', '.workflow/verification.yaml'),
  [string]$ExpectedArtifact = 'A concise worker receipt.',
  [switch]$WriteFile,
  [switch]$Json
)

$ErrorActionPreference = 'Stop'

if (-not (Test-Path -LiteralPath $ProjectPath -PathType Container)) {
  throw "ProjectPath does not exist or is not a directory: $ProjectPath"
}

$project = (Resolve-Path -LiteralPath $ProjectPath).Path
$dispatchDir = Join-Path $project '.workflow\dispatch'
$receiptTemplate = '.workflow/templates/worker_receipt.yaml'

function Format-ListBlock {
  param([string[]]$Items, [string]$Fallback)
  if ($Items.Count -eq 0) {
    return "- $Fallback"
  }
  return (($Items | ForEach-Object { "- $_" }) -join [Environment]::NewLine)
}

$mayReadBlock = Format-ListBlock -Items $MayRead -Fallback 'Use only the files needed for the bounded task.'
$mayEditBlock = Format-ListBlock -Items $MayEdit -Fallback 'No edits unless the main prompt explicitly allows them.'
$mustNotBlock = Format-ListBlock -Items $MustNotEdit -Fallback 'Do not edit unrelated files.'

$prompt = @"
You are a bounded worker for this project.

Task id:
$TaskId

Task:
$Task

Scope:
$Scope

May read:
$mayReadBlock

May edit:
$mayEditBlock

Must not edit:
$mustNotBlock

Expected artifact:
$ExpectedArtifact

Rules:
- Do not decide product direction or final acceptance.
- Do not overwrite unrelated work.
- Keep the task bounded; stop and report if scope is too broad.
- Return a receipt using $receiptTemplate.
- Include status, files_read, files_changed, commands_run, evidence, proves, does_not_prove, risks, open_threads, and next_recommended_step.
- Say explicitly what your work does not prove.
"@

$outPath = $null
if ($WriteFile) {
  if (-not (Test-Path -LiteralPath $dispatchDir -PathType Container)) {
    New-Item -ItemType Directory -Path $dispatchDir -Force | Out-Null
  }
  $safeTaskId = ($TaskId -replace '[^A-Za-z0-9_.-]', '-').Trim('-')
  if ([string]::IsNullOrWhiteSpace($safeTaskId)) {
    $safeTaskId = 'worker-task'
  }
  $outPath = Join-Path $dispatchDir "$safeTaskId-worker-prompt.md"
  Set-Content -LiteralPath $outPath -Value $prompt -Encoding UTF8
}

$result = [ordered]@{
  project = $project
  task_id = $TaskId
  scope = $Scope
  receipt_template = $receiptTemplate
  written_to = $outPath
  prompt = $prompt
}

if ($Json) {
  $result | ConvertTo-Json -Depth 6
  exit 0
}

Write-Output $prompt
if ($outPath) {
  Write-Output ""
  Write-Output "Written to: $outPath"
}
