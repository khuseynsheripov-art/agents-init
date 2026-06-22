[CmdletBinding()]
param(
  [Parameter(Mandatory = $true)]
  [string]$ProjectPath,

  [Parameter(Mandatory = $true)]
  [ValidateSet('diagnose', 'search', 'spec', 'knowhow', 'wiki', 'kg', 'domain', 'workspace', 'msg', 'overlay', 'delegate-config')]
  [string]$Skill,

  [string]$Query = '',

  [ValidateSet('status', 'list', 'search', 'get', 'index', 'sync', 'context', 'diff', 'show')]
  [string]$Action = '',

  [string]$Id = '',

  [switch]$All,

  [switch]$Json
)

$ErrorActionPreference = 'Stop'

# Command catalog intentionally keeps literal strings visible for policy tests and
# for main agents reviewing what this wrapper can really invoke:
# - maestro search <query> --all
# - maestro spec status | list | search <query>
# - maestro knowhow list | search <query> | get <id>
# - maestro kg stats | index | sync | search <query> | context <id> | diff
# - maestro wiki search <query>
# - maestro domain list | search <query>
# - maestro workspace status
# - maestro msg list
# - maestro overlay list
# - maestro config delegate show

function Invoke-MaestroCommand {
  param(
    [Parameter(Mandatory = $true)][string[]]$Arguments,
    [Parameter(Mandatory = $true)][string]$WorkingDirectory
  )

  $oldLocation = Get-Location
  $oldErrorActionPreference = $ErrorActionPreference
  try {
    Set-Location -LiteralPath $WorkingDirectory
    $ErrorActionPreference = 'Continue'
    $output = & maestro @Arguments 2>&1
    $exitCode = $LASTEXITCODE
    if ($null -eq $exitCode) {
      $exitCode = 0
    }
    return [ordered]@{
      ok = $exitCode -eq 0
      exit_code = $exitCode
      text = (($output | ForEach-Object { $_.ToString() }) -join [Environment]::NewLine).Trim()
    }
  } catch {
    return [ordered]@{
      ok = $false
      exit_code = 1
      text = $_.Exception.Message
    }
  } finally {
    $ErrorActionPreference = $oldErrorActionPreference
    Set-Location -LiteralPath $oldLocation
  }
}

if (-not (Test-Path -LiteralPath $ProjectPath -PathType Container)) {
  throw "ProjectPath does not exist or is not a directory: $ProjectPath"
}

$project = (Resolve-Path -LiteralPath $ProjectPath).Path
$arguments = @()
$defaultAction = ''

switch ($Skill) {
  'diagnose' {
    $arguments = @('--version')
  }
  'search' {
    if ([string]::IsNullOrWhiteSpace($Query)) {
      throw "Skill search requires -Query."
    }
    $arguments = @('search') + ($Query -split '\s+')
    if ($All) { $arguments += '--all' }
  }
  'spec' {
    $defaultAction = if ([string]::IsNullOrWhiteSpace($Action)) { 'search' } else { $Action }
    if ($defaultAction -eq 'status') {
      $arguments = @('spec', 'status')
    } elseif ($defaultAction -eq 'list') {
      $arguments = @('spec', 'list')
    } else {
      if ([string]::IsNullOrWhiteSpace($Query)) { throw "Skill spec search requires -Query, or use -Action status/list." }
      $arguments = @('spec', 'search') + ($Query -split '\s+')
    }
  }
  'knowhow' {
    $defaultAction = if ([string]::IsNullOrWhiteSpace($Action)) { 'search' } else { $Action }
    if ($defaultAction -eq 'list') {
      $arguments = @('knowhow', 'list')
    } elseif ($defaultAction -eq 'get') {
      if ([string]::IsNullOrWhiteSpace($Id)) { throw "Skill knowhow get requires -Id." }
      $arguments = @('knowhow', 'get', $Id)
    } else {
      if ([string]::IsNullOrWhiteSpace($Query)) { throw "Skill knowhow search requires -Query, or use -Action list/get." }
      $arguments = @('knowhow', 'search') + ($Query -split '\s+')
    }
  }
  'wiki' {
    if ([string]::IsNullOrWhiteSpace($Query)) { throw "Skill wiki requires -Query." }
    $arguments = @('wiki', 'search') + ($Query -split '\s+')
  }
  'kg' {
    $defaultAction = if ([string]::IsNullOrWhiteSpace($Action)) { 'search' } else { $Action }
    if ($defaultAction -eq 'status') {
      $arguments = @('kg', 'stats')
    } elseif ($defaultAction -eq 'index') {
      $arguments = @('kg', 'index')
    } elseif ($defaultAction -eq 'sync') {
      $arguments = @('kg', 'sync')
    } elseif ($defaultAction -eq 'context') {
      if ([string]::IsNullOrWhiteSpace($Id)) { throw "Skill kg context requires -Id." }
      $arguments = @('kg', 'context', $Id)
    } elseif ($defaultAction -eq 'diff') {
      $arguments = @('kg', 'diff')
    } else {
      if ([string]::IsNullOrWhiteSpace($Query)) { throw "Skill kg search requires -Query, or use -Action status/index/sync/diff/context." }
      $arguments = @('kg', 'search') + ($Query -split '\s+')
    }
  }
  'domain' {
    $defaultAction = if ([string]::IsNullOrWhiteSpace($Action)) { 'list' } else { $Action }
    if ($defaultAction -eq 'search') {
      if ([string]::IsNullOrWhiteSpace($Query)) { throw "Skill domain search requires -Query." }
      $arguments = @('domain', 'search') + ($Query -split '\s+')
    } else {
      $arguments = @('domain', 'list')
    }
  }
  'workspace' {
    $arguments = @('workspace', 'status')
  }
  'msg' {
    $arguments = @('msg', 'list')
  }
  'overlay' {
    $arguments = @('overlay', 'list')
  }
  'delegate-config' {
    $arguments = @('config', 'delegate', 'show')
  }
}

$commandText = 'maestro ' + ($arguments -join ' ')
$run = Invoke-MaestroCommand -Arguments $arguments -WorkingDirectory $project
$rawOutputNonEmpty = -not [string]::IsNullOrWhiteSpace($run.text)

$proves = @()
if ($run.ok) {
  $proves += "Maestro command executed for skill surface: $Skill."
  if ($rawOutputNonEmpty) {
    $proves += 'Raw output was captured for main-agent inspection.'
  }
}

$doesNotProve = @(
  'Claude delegate review happened',
  'multi-model review happened',
  'user accepted a product/UI/sample decision',
  'Ralph or Maestro should auto-advance past human gates',
  'retrieved anchors are sufficient without main-agent synthesis'
)
if (-not $run.ok) {
  $doesNotProve += 'Maestro skill surface is usable for this project without repair.'
}
if (-not $rawOutputNonEmpty) {
  $doesNotProve += 'The command returned usable anchors.'
}
if ($Skill -eq 'kg' -and $arguments -contains 'index') {
  $doesNotProve += 'KG search/context was used after indexing.'
}

$result = [ordered]@{
  project = $project
  route = 'maestro_skill'
  skill = $Skill
  action = if ([string]::IsNullOrWhiteSpace($Action)) { $defaultAction } else { $Action }
  query = $Query
  id = $Id
  command = $commandText
  exit_code = $run.exit_code
  ok = $run.ok
  raw_output_non_empty = $rawOutputNonEmpty
  output = $run.text
  proves = $proves
  does_not_prove = $doesNotProve
  next_main_agent_step = 'Cite only task-relevant anchors, fill proves/does_not_prove, then decide direct/worker/Maestro/Ralph/human gate.'
}

if ($Json) {
  $result | ConvertTo-Json -Depth 8
} else {
  Write-Output "Agents Init Maestro Skill"
  Write-Output "Project: $project"
  Write-Output "Skill: $Skill"
  Write-Output "Command: $commandText"
  Write-Output "OK: $($run.ok)"
  Write-Output "Raw output non-empty: $rawOutputNonEmpty"
  Write-Output ""
  Write-Output $run.text
}

if (-not $run.ok) {
  exit 1
}
