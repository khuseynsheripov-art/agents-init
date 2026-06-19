[CmdletBinding()]
param(
  [string]$CodexHome = "$env:USERPROFILE\.codex"
)

$ErrorActionPreference = 'Stop'

$repoRoot = Resolve-Path -LiteralPath (Join-Path $PSScriptRoot '..')
$source = Join-Path $CodexHome 'skills\agents-init'
$target = Join-Path $repoRoot 'skill\agents-init'

if (-not (Test-Path -LiteralPath $source -PathType Container)) {
  throw "Installed skill not found: $source"
}

if (Test-Path -LiteralPath $target -PathType Container) {
  Remove-Item -LiteralPath $target -Recurse -Force
}

Copy-Item -LiteralPath $source -Destination $target -Recurse -Force
Write-Output "Synced installed skill from $source to $target"

