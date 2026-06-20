[CmdletBinding()]
param(
  [string]$RepoUrl = "https://github.com/khuseynsheripov-art/agents-init.git",
  [string]$Branch = "main",
  [string]$CodexHome = "$env:USERPROFILE\.codex",
  [string]$SourceRoot = "$env:USERPROFILE\.codex\skill-sources\agents-init",
  [string]$ProjectPath = "",
  [switch]$NoBackup,
  [switch]$SkipProjectUpgrade
)

$ErrorActionPreference = 'Stop'

function Invoke-Checked {
  param(
    [Parameter(Mandatory = $true)][string]$FilePath,
    [Parameter(Mandatory = $true)][string[]]$Arguments,
    [string]$WorkingDirectory = ""
  )

  $oldLocation = Get-Location
  try {
    if ($WorkingDirectory) {
      Set-Location -LiteralPath $WorkingDirectory
    }
    & $FilePath @Arguments
    if ($LASTEXITCODE -ne 0) {
      throw "Command failed with exit code ${LASTEXITCODE}: $FilePath $($Arguments -join ' ')"
    }
  } finally {
    Set-Location -LiteralPath $oldLocation
  }
}

$sourceParent = Split-Path -Parent $SourceRoot
New-Item -ItemType Directory -Force -Path $sourceParent | Out-Null

if (-not (Test-Path -LiteralPath (Join-Path $SourceRoot '.git') -PathType Container)) {
  if (Test-Path -LiteralPath $SourceRoot) {
    throw "SourceRoot exists but is not a git clone: $SourceRoot"
  }
  Invoke-Checked -FilePath 'git' -Arguments @('clone', '--branch', $Branch, $RepoUrl, $SourceRoot)
} else {
  Invoke-Checked -FilePath 'git' -Arguments @('fetch', 'origin', $Branch) -WorkingDirectory $SourceRoot
  Invoke-Checked -FilePath 'git' -Arguments @('pull', '--ff-only', 'origin', $Branch) -WorkingDirectory $SourceRoot
}

$installScript = Join-Path $SourceRoot 'scripts\install-local.ps1'
if (-not (Test-Path -LiteralPath $installScript -PathType Leaf)) {
  throw "Install script not found after update: $installScript"
}

$installArgs = @('-NoProfile', '-ExecutionPolicy', 'Bypass', '-File', $installScript, '-CodexHome', $CodexHome)
if ($NoBackup) {
  $installArgs += '-NoBackup'
}
Invoke-Checked -FilePath 'powershell' -Arguments $installArgs

$projectUpgrade = $null
if ($ProjectPath -and -not $SkipProjectUpgrade) {
  $initScript = Join-Path $CodexHome 'skills\agents-init\scripts\init-agents.ps1'
  $validateScript = Join-Path $CodexHome 'skills\agents-init\scripts\validate-workflow.ps1'
  Invoke-Checked -FilePath 'powershell' -Arguments @('-NoProfile', '-ExecutionPolicy', 'Bypass', '-File', $initScript, '-ProjectPath', $ProjectPath, '-Mode', 'upgrade')
  Invoke-Checked -FilePath 'powershell' -Arguments @('-NoProfile', '-ExecutionPolicy', 'Bypass', '-File', $validateScript, '-ProjectPath', $ProjectPath, '-Json')
  $projectUpgrade = [ordered]@{
    project = $ProjectPath
    mode = 'upgrade_and_validate'
  }
}

[pscustomobject][ordered]@{
  status = 'updated'
  repo_url = $RepoUrl
  branch = $Branch
  source_root = (Resolve-Path -LiteralPath $SourceRoot).Path
  codex_home = $CodexHome
  project_upgrade = $projectUpgrade
  next = 'Use init-agents.ps1 -Mode upgrade for each business project that should receive workflow template updates.'
} | ConvertTo-Json -Depth 6
