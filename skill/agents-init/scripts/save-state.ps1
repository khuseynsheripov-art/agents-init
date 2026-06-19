[CmdletBinding()]
param(
  [Parameter(Mandatory = $true)]
  [string]$ProjectPath,

  [string]$OutPath = '',

  [switch]$NoWrite,
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

if (-not (Test-Path -LiteralPath $ProjectPath -PathType Container)) {
  throw "ProjectPath does not exist or is not a directory: $ProjectPath"
}

$project = (Resolve-Path -LiteralPath $ProjectPath).Path
$workflow = Join-Path $project '.workflow'
if (-not (Test-Path -LiteralPath $workflow -PathType Container)) {
  throw "Project does not have a .workflow directory. Run init-agents.ps1 -Mode auto first."
}

$current = Read-TextOrEmpty (Join-Path $workflow 'current.yaml')
$task = Read-TextOrEmpty (Join-Path $workflow 'task.yaml')
$openThreads = Read-TextOrEmpty (Join-Path $workflow 'open_threads.yaml')
$verification = Read-TextOrEmpty (Join-Path $workflow 'verification.yaml')
$threadRegistry = Read-TextOrEmpty (Join-Path $workflow 'thread_registry.yaml')

$goal = Get-FirstMatch $current '(?m)^\s*mission:\s*(.+)$' '<unknown>'
$gate = Get-FirstMatch $current '(?m)^\s*current_gate:\s*(.+)$' '<unknown>'
$status = Get-FirstMatch $current '(?m)^\s*status:\s*(.+)$' '<unknown>'
$activeTask = Get-FirstMatch $task '(?m)^\s*active_task:\s*(.+)$' '<unknown>'
$nextAction = Get-FirstMatch $current '(?m)^\s*next_action:\s*(.+)$' '<unknown>'
$mainThread = Get-FirstMatch $threadRegistry '(?m)^\s*id:\s*(.+)$' '<unknown>'

$openCount = ([regex]::Matches($openThreads, '(?m)^\s*-\s+id:')).Count
$verificationCount = ([regex]::Matches($verification, '(?m)^\s*-\s+id:')).Count

$brief = @"
# Session Recovery Brief

Generated at: $(Get-Date -Format s)
Project: $project

## Recovered Goal
$goal

## Status
$status

## Current Gate
$gate

## Active Task
$activeTask

## Main Thread
$mainThread

## Open Threads
Count: $openCount

Use .workflow/open_threads.yaml as the source of truth.

## Evidence
Verification entries: $verificationCount

Use .workflow/verification.yaml as the source of truth.

## Forbidden Claims
- Do not claim UI/UX acceptance without visible evidence and user acceptance.
- Do not claim generated image quality without user-visible output and acceptance.
- Do not claim worker/delegate output is accepted before main-agent ingest.
- Do not claim external publish/export/seller-ready status without explicit approval.

## Next Action
$nextAction

## First Prompt For Next Session
Use `$agents-init recover` for this project. Read .workflow/current.yaml, task.yaml, open_threads.yaml, verification.yaml, and thread_registry.yaml. Continue from gate "$gate" with active task "$activeTask". Do not ask the user to repeat the full history.
"@

if ([string]::IsNullOrWhiteSpace($OutPath)) {
  $OutPath = Join-Path $workflow 'session-recovery-brief.md'
}

$written = $null
if (-not $NoWrite) {
  $parent = Split-Path -Parent $OutPath
  if (-not (Test-Path -LiteralPath $parent -PathType Container)) {
    New-Item -ItemType Directory -Path $parent -Force | Out-Null
  }
  Set-Content -LiteralPath $OutPath -Value $brief -Encoding UTF8
  $written = (Resolve-Path -LiteralPath $OutPath).Path
}

$result = [ordered]@{
  project = $project
  status = $status
  recovered_goal = $goal
  current_gate = $gate
  active_task = $activeTask
  main_thread = $mainThread
  open_thread_count = $openCount
  verification_entry_count = $verificationCount
  next_action = $nextAction
  written_to = $written
  brief = $brief
}

if ($Json) {
  $result | ConvertTo-Json -Depth 6
  exit 0
}

Write-Output $brief
if ($written) {
  Write-Output ""
  Write-Output "Written to: $written"
}
