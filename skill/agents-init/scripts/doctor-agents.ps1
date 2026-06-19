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
