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

$invokeClaude = Join-Path $skillRoot 'scripts\invoke-claude-review.ps1'
Assert-True (Test-Path -LiteralPath $invokeClaude -PathType Leaf) 'agents-init must include invoke-claude-review.ps1 so other sessions can actually call Claude and read raw output.'
$invokeClaudeText = Read-Text $invokeClaude
Assert-True ($invokeClaudeText -match 'maestro delegate output' -and $invokeClaudeText -match 'raw_output_non_empty' -and $invokeClaudeText -match 'exec_id') 'invoke-claude-review.ps1 must call Maestro delegate, read delegate output, and report exec_id/raw_output_non_empty.'

$modelPolicyTemplate = Read-Text (Join-Path $skillRoot 'assets\project-template\.workflow\model_policy.yaml')
Assert-True ($modelPolicyTemplate -match 'preferred_route: maestro_delegate_when_raw_output_proven' -and $modelPolicyTemplate -match 'cc2_profile_reference') 'model_policy template must encode Maestro delegate as preferred proven lifecycle and cc2 as a local profile reference/fallback.'

$caseStudy = Read-Text (Join-Path $skillRoot 'references\case-studies\ozon-canvas.md')
Assert-True ($caseStudy -match '/image mainline integration vs /canvas/ozon-suite sidecar drift') 'Ozon/Canvas case study must name the required first diagnosis exactly.'

$initScript = Join-Path $skillRoot 'scripts\init-agents.ps1'
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

  Assert-True ($upgradedAgents -match 'protocol_version:\s*2') 'Upgrade must refresh .workflow/agents-init.yaml to protocol_version 2.'
  Assert-True ($upgradedAgents -match 'active_thread_id:\s*"thread-keep-me"') 'Upgrade must preserve the project active_thread_id while refreshing managed agents-init.yaml content.'
  Assert-True ($upgradedAgents.IndexOf($badChar) -lt 0) 'Upgrade must replace mojibake in managed agents-init.yaml content.'
  Assert-True ($upgradedDecision -match 'route:\s*none \| delegate \| ralph \| spec \| knowhow \| search \| kg \| msg \| overlay') 'Upgrade must refresh stale orchestration decision template route options.'
  Assert-True ($upgradedDecision -match 'lifecycle:\s*one_shot \| continuous') 'Upgrade must refresh stale Codex App worker lifecycle fields.'
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

if (Test-Path -LiteralPath (Join-Path $SampleProject '.workflow\current.yaml') -PathType Leaf) {
  $sampleCurrent = Read-Text (Join-Path $SampleProject '.workflow\current.yaml')
  Assert-True ($sampleCurrent -match '/image' -and $sampleCurrent -match '/canvas/ozon-suite' -and $sampleCurrent -match 'sidecar') 'Sample workflow current.yaml must foreground /image mainline vs /canvas/ozon-suite sidecar drift.'
}

[pscustomobject][ordered]@{
  status = 'passed'
  checked_files = $skillFiles.Count
  sample_project_checked = (Test-Path -LiteralPath (Join-Path $SampleProject '.workflow\current.yaml') -PathType Leaf)
} | ConvertTo-Json -Depth 4
