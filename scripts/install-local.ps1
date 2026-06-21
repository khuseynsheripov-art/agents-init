[CmdletBinding()]
param(
  [string]$CodexHome = "$env:USERPROFILE\.codex",
  [switch]$NoBackup
)

$ErrorActionPreference = 'Stop'

$repoRoot = Resolve-Path -LiteralPath (Join-Path $PSScriptRoot '..')
$source = Join-Path $repoRoot 'skill\agents-init'
$targetRoot = Join-Path $CodexHome 'skills'
$target = Join-Path $targetRoot 'agents-init'
$backupRoot = Join-Path $CodexHome 'skill-backups\agents-init'

if (-not (Test-Path -LiteralPath $source -PathType Container)) {
  throw "Skill source not found: $source"
}

New-Item -ItemType Directory -Force -Path $targetRoot | Out-Null
New-Item -ItemType Directory -Force -Path $backupRoot | Out-Null

$discoverableBackups = Get-ChildItem -LiteralPath $targetRoot -Directory -Filter 'agents-init.backup.*' -ErrorAction SilentlyContinue
foreach ($entry in $discoverableBackups) {
  $dest = Join-Path $backupRoot $entry.Name
  if (Test-Path -LiteralPath $dest) {
    $dest = Join-Path $backupRoot ($entry.Name + '.quarantine.' + (Get-Date -Format 'yyyyMMdd-HHmmss'))
  }
  Move-Item -LiteralPath $entry.FullName -Destination $dest
  Write-Output "Moved discoverable backup skill out of skills root to $dest"
}

if ((Test-Path -LiteralPath $target -PathType Container) -and -not $NoBackup) {
  $stamp = Get-Date -Format 'yyyyMMdd-HHmmss'
  $backup = Join-Path $backupRoot "agents-init.backup.$stamp"
  Copy-Item -LiteralPath $target -Destination $backup -Recurse -Force
  Write-Output "Backed up existing skill to $backup"
}

if (Test-Path -LiteralPath $target -PathType Container) {
  Remove-Item -LiteralPath $target -Recurse -Force
}

Copy-Item -LiteralPath $source -Destination $target -Recurse -Force
Write-Output "Installed agents-init skill to $target"
