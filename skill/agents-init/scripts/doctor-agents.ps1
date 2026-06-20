[CmdletBinding()]
param(
  [Parameter(Mandatory = $true)]
  [string]$ProjectPath,

  [switch]$Json
)

$ErrorActionPreference = 'Stop'

function Invoke-TextCommand {
  param(
    [Parameter(Mandatory = $true)][string]$FilePath,
    [Parameter(Mandatory = $true)][string[]]$Arguments,
    [string]$WorkingDirectory = $ProjectPath
  )

  $oldLocation = Get-Location
  try {
    Set-Location -LiteralPath $WorkingDirectory
    $output = & $FilePath @Arguments 2>&1
    $exitCode = $LASTEXITCODE
    if ($null -eq $exitCode) {
      $exitCode = 0
    }
    return [ordered]@{
      ok = $exitCode -eq 0
      exit_code = $exitCode
      stdout = (($output | ForEach-Object { $_.ToString() }) -join [Environment]::NewLine).Trim()
      stderr = ''
    }
  } catch {
    return [ordered]@{
      ok = $false
      exit_code = $null
      stdout = ''
      stderr = $_.Exception.Message
    }
  } finally {
    Set-Location -LiteralPath $oldLocation
  }
}

function Get-CommandRoute {
  param([Parameter(Mandatory = $true)][string]$Name)

  $command = Get-Command $Name -ErrorAction SilentlyContinue
  if (-not $command) {
    $profileProbe = Invoke-TextCommand -FilePath $currentShell -Arguments @('-ExecutionPolicy','Bypass','-Command',"`$c = Get-Command $Name -ErrorAction SilentlyContinue; if (`$c) { [pscustomobject][ordered]@{ name = `$c.Name; command_type = [string]`$c.CommandType; source = [string]`$c.Source; definition = [string]`$c.Definition; version = [string]`$c.Version } | ConvertTo-Json -Compress }") -WorkingDirectory $project
    if (-not $profileProbe.ok -or [string]::IsNullOrWhiteSpace($profileProbe.stdout)) {
      return [ordered]@{
        name = $Name
        found = $false
        command_type = ''
        source = ''
        version = ''
        profile_hint = ''
        route_kind = 'missing'
        discovery_scope = 'current_process_and_profile_shell'
      }
    }
    try {
      $profileCommand = $profileProbe.stdout | ConvertFrom-Json
      $definition = [string]$profileCommand.definition
      $profileHint = ''
      if ($definition -match 'CLAUDE_CONFIG_DIR\s*=\s*"([^"]+)"') {
        $profileHint = $Matches[1]
      } elseif ($definition -match 'CLAUDE_CONFIG_DIR') {
        $profileHint = 'sets_CLAUDE_CONFIG_DIR'
      }
      return [ordered]@{
        name = $Name
        found = $true
        command_type = [string]$profileCommand.command_type
        source = [string]$profileCommand.source
        version = [string]$profileCommand.version
        profile_hint = $profileHint
        route_kind = if ([string]$profileCommand.command_type -eq 'Function') { 'wrapper_or_profile_route' } else { 'direct_application_route' }
        discovery_scope = 'profile_loaded_shell'
      }
    } catch {
      return [ordered]@{
        name = $Name
        found = $false
        command_type = ''
        source = ''
        version = ''
        profile_hint = ''
        route_kind = 'missing'
        discovery_scope = 'profile_loaded_shell_parse_failed'
      }
    }
  }

  $definition = if ($command.PSObject.Properties.Name -contains 'Definition') { [string]$command.Definition } else { '' }
  $source = if ($command.PSObject.Properties.Name -contains 'Source') { [string]$command.Source } else { '' }
  $version = if ($command.PSObject.Properties.Name -contains 'Version') { [string]$command.Version } else { '' }
  $profileHint = ''
  if ($definition -match 'CLAUDE_CONFIG_DIR\s*=\s*"([^"]+)"') {
    $profileHint = $Matches[1]
  } elseif ($definition -match 'CLAUDE_CONFIG_DIR') {
    $profileHint = 'sets_CLAUDE_CONFIG_DIR'
  }

  return [ordered]@{
    name = $Name
    found = $true
    command_type = [string]$command.CommandType
    source = $source
    version = $version
    profile_hint = $profileHint
    route_kind = if ($command.CommandType -eq 'Function') { 'wrapper_or_profile_route' } else { 'direct_application_route' }
    discovery_scope = 'current_process'
  }
}

if (-not (Test-Path -LiteralPath $ProjectPath -PathType Container)) {
  throw "ProjectPath does not exist or is not a directory: $ProjectPath"
}

$project = (Resolve-Path -LiteralPath $ProjectPath).Path
$skillRoot = Split-Path -Parent $PSScriptRoot
$currentShell = (Get-Process -Id $PID).Path
if ([string]::IsNullOrWhiteSpace($currentShell) -or -not (Test-Path -LiteralPath $currentShell -PathType Leaf)) {
  $currentShell = Join-Path $PSHOME 'powershell.exe'
}

$recoverScript = Join-Path $PSScriptRoot 'recover-agents.ps1'
$validateScript = Join-Path $PSScriptRoot 'validate-workflow.ps1'

$recover = Invoke-TextCommand -FilePath $currentShell -Arguments @('-NoProfile','-ExecutionPolicy','Bypass','-File',$recoverScript,'-ProjectPath',$project,'-Json') -WorkingDirectory $project
$validate = Invoke-TextCommand -FilePath $currentShell -Arguments @('-NoProfile','-ExecutionPolicy','Bypass','-File',$validateScript,'-ProjectPath',$project,'-Json') -WorkingDirectory $project

$maestroVersion = Invoke-TextCommand -FilePath 'cmd.exe' -Arguments @('/c','maestro --version') -WorkingDirectory $project
$maestroSpec = Invoke-TextCommand -FilePath 'cmd.exe' -Arguments @('/c','maestro spec status') -WorkingDirectory $project
$maestroKnowhow = Invoke-TextCommand -FilePath 'cmd.exe' -Arguments @('/c','maestro knowhow list') -WorkingDirectory $project
$maestroDelegate = Invoke-TextCommand -FilePath 'cmd.exe' -Arguments @('/c','maestro config delegate show') -WorkingDirectory $project

$maestroCommand = Invoke-TextCommand -FilePath 'cmd.exe' -Arguments @('/c','powershell -NoProfile -Command "Get-Command maestro | Select-Object -ExpandProperty Source"') -WorkingDirectory $project
$cc2Route = Get-CommandRoute -Name 'cc2'
$claudeRoute = Get-CommandRoute -Name 'claude'
$cc2VersionArgs = if ($cc2Route.found -and $cc2Route.discovery_scope -eq 'profile_loaded_shell') { @('-ExecutionPolicy','Bypass','-Command','cc2 --version') } else { @('-NoProfile','-ExecutionPolicy','Bypass','-Command','cc2 --version') }
$claudeVersionArgs = if ($claudeRoute.found -and $claudeRoute.discovery_scope -eq 'profile_loaded_shell') { @('-ExecutionPolicy','Bypass','-Command','claude --version') } else { @('-NoProfile','-ExecutionPolicy','Bypass','-Command','claude --version') }
$cc2Version = if ($cc2Route.found) { Invoke-TextCommand -FilePath $currentShell -Arguments $cc2VersionArgs -WorkingDirectory $project } else { $null }
$claudeVersion = if ($claudeRoute.found) { Invoke-TextCommand -FilePath $currentShell -Arguments $claudeVersionArgs -WorkingDirectory $project } else { $null }
$workspaceMaestroConfig = Join-Path $project '.maestro\cli-tools.json'
$globalMaestroConfig = Join-Path $HOME '.maestro\cli-tools.json'
$maestroConfigSource = if (Test-Path -LiteralPath $workspaceMaestroConfig -PathType Leaf) {
  'workspace'
} elseif (Test-Path -LiteralPath $globalMaestroConfig -PathType Leaf) {
  'global'
} else {
  'default'
}

$isWindows = [System.Runtime.InteropServices.RuntimeInformation]::IsOSPlatform([System.Runtime.InteropServices.OSPlatform]::Windows)
$terminalBackendHint = if ($env:TMUX -or $env:WEZTERM_PANE) { 'terminal_backend_possible' } else { 'terminal_backend_not_detected' }

$result = [ordered]@{
  project = $project
  workflow = [ordered]@{
    recover_ok = $recover.ok
    validate_ok = $validate.ok
    recover = $recover.stdout
    recover_error = $recover.stderr
    validate = $validate.stdout
    validate_error = $validate.stderr
  }
  maestro = [ordered]@{
    installed = $maestroVersion.ok
    version = $maestroVersion.stdout
    version_error = $maestroVersion.stderr
    binary = $maestroCommand.stdout
    config_source = $maestroConfigSource
    workspace_config = $workspaceMaestroConfig
    global_config = $globalMaestroConfig
    spec_status_ok = $maestroSpec.ok
    spec_status = $maestroSpec.stdout
    spec_status_error = $maestroSpec.stderr
    knowhow_ok = $maestroKnowhow.ok
    knowhow = $maestroKnowhow.stdout
    knowhow_error = $maestroKnowhow.stderr
    delegate_config_ok = $maestroDelegate.ok
    delegate_config = $maestroDelegate.stdout
    delegate_config_error = $maestroDelegate.stderr
  }
  claude_command_routes = [ordered]@{
    cc2 = [ordered]@{
      discovery = $cc2Route
      version_ok = if ($cc2Version) { $cc2Version.ok } else { $false }
      version = if ($cc2Version) { $cc2Version.stdout } else { '' }
      version_error = if ($cc2Version) { $cc2Version.stderr } else { '' }
      status = if ($cc2Route.found) { 'discovered_needs_smoke_before_review_claim' } else { 'not_found' }
    }
    claude = [ordered]@{
      discovery = $claudeRoute
      version_ok = if ($claudeVersion) { $claudeVersion.ok } else { $false }
      version = if ($claudeVersion) { $claudeVersion.stdout } else { '' }
      version_error = if ($claudeVersion) { $claudeVersion.stderr } else { '' }
      status = if ($claudeRoute.found) { 'discovered_needs_profile_specific_smoke_before_use' } else { 'not_found' }
    }
    preferred_policy = 'prefer_project_approved_wrapper_after_exact_smoke; do_not_treat_default_claude_failure_as_cc2_failure'
    verification_boundary = 'discovery_and_version_are_not_model_review_receipts'
  }
  environment = [ordered]@{
    os = if ($isWindows) { 'windows' } else { 'non_windows' }
    codex_hooks_reliability = if ($isWindows) { 'do_not_rely_on_codex_hooks_on_windows' } else { 'check_maestro_hooks_status' }
    terminal_backend = $terminalBackendHint
  }
  recommendations = @()
  verification_level = 'doctor_checks_environment_and_workflow_only_not_live_task_proof'
}

if (-not $recover.ok) { $result.recommendations += 'Fix workflow recovery before long tasks.' }
if (-not $validate.ok) { $result.recommendations += 'Fix workflow validation errors before claiming configured.' }
if (-not $maestroVersion.ok) { $result.recommendations += 'Install or repair Maestro before using Maestro/Ralph routes.' }
if ($maestroConfigSource -eq 'global') { $result.recommendations += 'Global Maestro config is active; require stronger confirmation before writing it and record rollback.' }
if ($cc2Route.found) { $result.recommendations += 'cc2 is available as a separate Claude route; smoke cc2 directly before using it as a review receipt.' }
if ($claudeRoute.found) { $result.recommendations += 'default claude is available as a separate route; do not prefer it over cc2 unless that exact profile smokes successfully.' }
if (-not $cc2Route.found -and -not $claudeRoute.found) { $result.recommendations += 'No direct Claude command was discovered; use interactive packet flow or local multi-perspective review.' }
if ($isWindows) { $result.recommendations += 'Use .workflow recovery files first; do not rely on Codex hooks on Windows.' }
if ($terminalBackendHint -eq 'terminal_backend_not_detected') { $result.recommendations += 'Prefer direct delegate or Codex App workers; terminal backend not detected.' }

if ($Json) {
  $result | ConvertTo-Json -Depth 8
  exit 0
}

Write-Output "Agents Init Doctor"
Write-Output "Project: $project"
Write-Output "Workflow recover: $($recover.ok)"
Write-Output "Workflow validate: $($validate.ok)"
Write-Output "Maestro installed: $($maestroVersion.ok) $($maestroVersion.stdout)"
Write-Output "Maestro binary: $($maestroCommand.stdout)"
Write-Output "Maestro config source: $maestroConfigSource"
Write-Output "Maestro spec status ok: $($maestroSpec.ok)"
Write-Output "Maestro knowhow ok: $($maestroKnowhow.ok)"
Write-Output "Maestro delegate config ok: $($maestroDelegate.ok)"
Write-Output "cc2 route: $($result.claude_command_routes.cc2.status)"
Write-Output "default claude route: $($result.claude_command_routes.claude.status)"
Write-Output "Codex hooks: $($result.environment.codex_hooks_reliability)"
Write-Output "Terminal backend: $($result.environment.terminal_backend)"
Write-Output ""
Write-Output "Recommendations:"
foreach ($item in $result.recommendations) {
  Write-Output "- $item"
}

if (-not $recover.ok -or -not $validate.ok) {
  exit 1
}
