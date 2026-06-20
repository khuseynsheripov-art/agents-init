[CmdletBinding()]
param(
  [Parameter(Mandatory = $true)]
  [string]$ProjectPath,

  [string]$Task,

  [ValidateSet('analysis', 'review', 'plan', 'brainstorm')]
  [string]$Mode = 'analysis',

  [string]$ExpectedToken = '',

  [int]$TimeoutSeconds = 240,

  [int]$PollSeconds = 5,

  [string]$ExecId = '',

  [switch]$Json
)

$ErrorActionPreference = 'Stop'

function Invoke-CapturedCommand {
  param(
    [Parameter(Mandatory = $true)][string]$FilePath,
    [Parameter(Mandatory = $true)][string[]]$Arguments,
    [Parameter(Mandatory = $true)][string]$WorkingDirectory
  )

  $oldLocation = Get-Location
  $oldErrorActionPreference = $ErrorActionPreference
  try {
    Set-Location -LiteralPath $WorkingDirectory
    $ErrorActionPreference = 'Continue'
    $output = & $FilePath @Arguments 2>&1
    $exitCode = $LASTEXITCODE
    if ($null -eq $exitCode) { $exitCode = 0 }
    return [ordered]@{
      exit_code = $exitCode
      text = (($output | ForEach-Object { $_.ToString() }) -join [Environment]::NewLine).Trim()
    }
  } catch {
    return [ordered]@{
      exit_code = 1
      text = $_.Exception.Message
    }
  } finally {
    $ErrorActionPreference = $oldErrorActionPreference
    Set-Location -LiteralPath $oldLocation
  }
}

function Get-AssistantOutputFromJsonl {
  param([string]$Path)
  if (-not $Path -or -not (Test-Path -LiteralPath $Path -PathType Leaf)) {
    return ''
  }

  $messages = New-Object System.Collections.Generic.List[string]
  foreach ($line in (Get-Content -Encoding UTF8 -LiteralPath $Path)) {
    if ([string]::IsNullOrWhiteSpace($line)) {
      continue
    }
    try {
      $event = $line | ConvertFrom-Json
    } catch {
      continue
    }
    if ($event.type -eq 'assistant_message' -and -not [string]::IsNullOrWhiteSpace([string]$event.content)) {
      $messages.Add([string]$event.content)
    }
  }
  return (($messages | Select-Object -Last 1) -join [Environment]::NewLine).Trim()
}

function Get-DelegateOutput {
  param(
    [Parameter(Mandatory = $true)][string]$Id,
    [Parameter(Mandatory = $true)][string]$WorkingDirectory
  )

  return Invoke-CapturedCommand -FilePath 'maestro' -Arguments @('delegate', 'output', $Id) -WorkingDirectory $WorkingDirectory
}

if (-not (Test-Path -LiteralPath $ProjectPath -PathType Container)) {
  throw "ProjectPath does not exist or is not a directory: $ProjectPath"
}

$project = (Resolve-Path -LiteralPath $ProjectPath).Path
$historyRoot = Join-Path $HOME '.maestro\cli-history'
$providedExecId = -not [string]::IsNullOrWhiteSpace($ExecId)
if (-not $providedExecId -and [string]::IsNullOrWhiteSpace($Task)) {
  throw "Task is required unless -ExecId is provided."
}
if (-not $providedExecId) {
  $ExecId = 'cld-agentsinit-' + (Get-Date -Format 'HHmmss') + '-' + (Get-Random -Minimum 1000 -Maximum 9999)
}

$launchExitCode = 0
$launchText = ''
if ($providedExecId) {
  $launchText = 'inspect_existing_exec_id'
} else {
  try {
    $timeoutMs = [Math]::Max(1000, $TimeoutSeconds * 1000)
    $launch = Invoke-CapturedCommand `
      -FilePath 'maestro' `
      -Arguments @('delegate', '--to', 'claude', '--mode', $Mode, '--cd', $project, '--id', $ExecId, '--timeout', ([string]$timeoutMs), $Task) `
      -WorkingDirectory $project
    $launchExitCode = $launch.exit_code
    $launchText = $launch.text
  } catch {
    $launchExitCode = 1
    $launchText = $_.Exception.Message
  }
}

$execId = $ExecId
$metaPath = Join-Path $historyRoot "$execId.meta.json"
$jsonlPath = Join-Path $historyRoot "$execId.jsonl"
$outputText = ''
$outputExitCode = 0
$outputSource = ''
$statusText = ''
$timedOut = $false
if ($execId) {
  $deadline = (Get-Date).AddSeconds($TimeoutSeconds)
  do {
    $delegateOutput = Get-DelegateOutput -Id $execId -WorkingDirectory $project
    $outputExitCode = $delegateOutput.exit_code
    if ($delegateOutput.exit_code -eq 0 -and -not [string]::IsNullOrWhiteSpace($delegateOutput.text)) {
      $outputText = $delegateOutput.text
      $outputSource = 'maestro delegate output'
    } else {
      $outputText = Get-AssistantOutputFromJsonl -Path $jsonlPath
      if (-not [string]::IsNullOrWhiteSpace($outputText)) {
        $outputSource = 'raw jsonl assistant_message'
      }
    }

    $hasOutput = -not [string]::IsNullOrWhiteSpace($outputText)
    $hasExpectedToken = if ([string]::IsNullOrWhiteSpace($ExpectedToken)) { $hasOutput } else { $outputText -match [regex]::Escape($ExpectedToken) }
    if ($hasOutput -and $hasExpectedToken) {
      break
    }
    if ($metaPath -and (Test-Path -LiteralPath $metaPath -PathType Leaf)) {
      try {
        $metaProbe = Get-Content -Raw -Encoding UTF8 -LiteralPath $metaPath | ConvertFrom-Json
        $statusText = "exitCode: $($metaProbe.exitCode); completedAt: $($metaProbe.completedAt)"
        if ($null -ne $metaProbe.exitCode -and -not $hasOutput) {
          $delegateOutput = Get-DelegateOutput -Id $execId -WorkingDirectory $project
          $outputExitCode = $delegateOutput.exit_code
          if ($delegateOutput.exit_code -eq 0 -and -not [string]::IsNullOrWhiteSpace($delegateOutput.text)) {
            $outputText = $delegateOutput.text
            $outputSource = 'maestro delegate output'
          }
          break
        }
      } catch {
        $statusText = ''
      }
    }
    if ((Get-Date) -ge $deadline) {
      break
    }
    Start-Sleep -Seconds $PollSeconds
  } while ((Get-Date) -lt $deadline)
  $timedOut = (Get-Date) -ge $deadline
}

$meta = $null
if ($metaPath -and (Test-Path -LiteralPath $metaPath -PathType Leaf)) {
  try {
    $meta = Get-Content -Raw -Encoding UTF8 -LiteralPath $metaPath | ConvertFrom-Json
  } catch {
    $meta = $null
  }
}

$rawOutputNonEmpty = -not [string]::IsNullOrWhiteSpace($outputText)
$expectedTokenFound = if ([string]::IsNullOrWhiteSpace($ExpectedToken)) { $null } else { $outputText -match [regex]::Escape($ExpectedToken) }
$usable = $launchExitCode -eq 0 -and $execId -and $rawOutputNonEmpty -and (($null -eq $expectedTokenFound) -or $expectedTokenFound)

$result = [ordered]@{
  project = $project
  route = 'maestro_delegate_explicit_to_claude'
  mode = $Mode
  command = 'maestro delegate --to claude --mode <mode> --cd <project> --id <execId> <task>; maestro delegate output <execId>'
  exec_id = $execId
  delegate_exit_code = $launchExitCode
  delegate_stdout = $launchText
  output_exit_code = $outputExitCode
  output_source = $outputSource
  status = $statusText
  timed_out = $timedOut
  raw_output_non_empty = $rawOutputNonEmpty
  expected_token = $ExpectedToken
  expected_token_found = $expectedTokenFound
  usable = [bool]$usable
  output = $outputText
  meta_path = $metaPath
  jsonl_path = $jsonlPath
  meta = $meta
  proves = @()
  does_not_prove = @(
    'live semantic rerun passed',
    'role mapping routes review/brainstorm to Claude',
    'Claude should decide product direction',
    'completed/meta alone is sufficient evidence'
  )
}

if ($usable) {
  $result.proves += 'Claude was invoked through Maestro delegate and raw output was read.'
} elseif (-not $execId) {
  $result.does_not_prove += 'Maestro produced a delegate exec id.'
} elseif (-not $rawOutputNonEmpty) {
  $result.does_not_prove += 'Claude returned usable raw output.'
} elseif ($false -eq $expectedTokenFound) {
  $result.does_not_prove += 'Expected smoke token was present in raw output.'
}

if ($Json) {
  Write-Output ($result | ConvertTo-Json -Depth 10)
} else {
  Write-Output "Agents Init Claude Review"
  Write-Output "Project: $project"
  Write-Output "ExecId: $execId"
  Write-Output "Usable: $($result.usable)"
  Write-Output "Raw output non-empty: $rawOutputNonEmpty"
  if (-not [string]::IsNullOrWhiteSpace($ExpectedToken)) {
    Write-Output "Expected token found: $expectedTokenFound"
  }
  Write-Output ""
  Write-Output $outputText
}

if (-not $usable) {
  exit 1
}
