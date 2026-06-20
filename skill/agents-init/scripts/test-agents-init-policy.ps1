[CmdletBinding()]
param(
  [string]$RepoRoot = '',
  [string]$SampleProject = 'E:\ozon-erp\.worktrees\maestro-canvas-v030-lab'
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

$mojibakePattern = New-CharClass @(
  0x951F, 0xFFFD, 0x6D93, 0x9438, 0x93C2, 0x9359, 0x9366, 0x93C8,
  0x941E, 0x704F, 0x95C7, 0x951B, 0x93C0, 0x7035, 0x95AB, 0x6F36,
  0x59AB, 0x6D60, 0x6F7F, 0x9286, 0x942A, 0x93AC, 0x95C4
)
$badFiles = @()
foreach ($file in $skillFiles) {
  if ($file.FullName -eq $PSCommandPath) {
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
  if ($file.FullName -eq $PSCommandPath) {
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

$caseStudy = Read-Text (Join-Path $skillRoot 'references\case-studies\ozon-canvas.md')
Assert-True ($caseStudy -match '/image mainline integration vs /canvas/ozon-suite sidecar drift') 'Ozon/Canvas case study must name the required first diagnosis exactly.'

if (Test-Path -LiteralPath (Join-Path $SampleProject '.workflow\current.yaml') -PathType Leaf) {
  $sampleCurrent = Read-Text (Join-Path $SampleProject '.workflow\current.yaml')
  Assert-True ($sampleCurrent -match '/image' -and $sampleCurrent -match '/canvas/ozon-suite' -and $sampleCurrent -match 'sidecar') 'Sample workflow current.yaml must foreground /image mainline vs /canvas/ozon-suite sidecar drift.'
}

[pscustomobject][ordered]@{
  status = 'passed'
  checked_files = $skillFiles.Count
  sample_project_checked = (Test-Path -LiteralPath (Join-Path $SampleProject '.workflow\current.yaml') -PathType Leaf)
} | ConvertTo-Json -Depth 4
