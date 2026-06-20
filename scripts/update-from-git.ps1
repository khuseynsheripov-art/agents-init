[CmdletBinding()]
param(
  [string]$Branch = "main",
  [string]$CodexHome = "$env:USERPROFILE\.codex",
  [switch]$NoBackup
)

$ErrorActionPreference = 'Stop'

$repoRoot = Resolve-Path -LiteralPath (Join-Path $PSScriptRoot '..')
$installScript = Join-Path $PSScriptRoot 'install-local.ps1'

if (-not (Test-Path -LiteralPath (Join-Path $repoRoot '.git') -PathType Container)) {
  throw "This script must be run from a cloned agents-init git repository: $repoRoot"
}

$oldLocation = Get-Location
try {
  Set-Location -LiteralPath $repoRoot
  git fetch origin $Branch
  git pull --ff-only origin $Branch
} finally {
  Set-Location -LiteralPath $oldLocation
}

$args = @('-NoProfile', '-ExecutionPolicy', 'Bypass', '-File', $installScript, '-CodexHome', $CodexHome)
if ($NoBackup) {
  $args += '-NoBackup'
}

& powershell @args
exit $LASTEXITCODE
