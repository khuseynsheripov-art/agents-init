[CmdletBinding()]
param(
  [Parameter(Mandatory = $true)]
  [string]$ProjectPath,

  [ValidateSet('route_change', 'gate_change', 'direction_correction', 'handoff', 'promotion', 'archive_cleanup', 'receipt_ingest', 'task_closeout')]
  [string]$Reason = 'route_change',

  [string]$TaskId = '',
  [string]$FromRoute = '',
  [string]$ToRoute = '',
  [string]$CurrentAuthority = '',
  [string]$SupersededArtifact = '',
  [string]$PromotedSpec = '',
  [string]$PromotedKnowhow = '',
  [string]$ArchiveRef = '',
  [string]$OpenThreadId = '',
  [string]$VerificationId = '',
  [string]$MemoryPointId = '',

  [switch]$DryRun,
  [switch]$Json
)

$ErrorActionPreference = 'Stop'

function Read-TextOrEmpty {
  param([Parameter(Mandatory = $true)][string]$Path)
  if (Test-Path -LiteralPath $Path -PathType Leaf) {
    return Get-Content -Raw -Encoding UTF8 -LiteralPath $Path
  }
  return ''
}

function Write-Utf8NoBom {
  param(
    [Parameter(Mandatory = $true)][string]$Path,
    [Parameter(Mandatory = $true)][string]$Text
  )
  $parent = Split-Path -Parent $Path
  if (-not (Test-Path -LiteralPath $parent -PathType Container)) {
    New-Item -ItemType Directory -Path $parent -Force | Out-Null
  }
  $normalized = ($Text -replace "`r`n", "`n") -replace "`r", "`n"
  $normalized = $normalized -replace "`n", "`r`n"
  $encoding = New-Object System.Text.UTF8Encoding($false)
  [System.IO.File]::WriteAllText($Path, $normalized, $encoding)
}

function Convert-ToYamlScalar {
  param([string]$Value)
  if ([string]::IsNullOrWhiteSpace($Value)) {
    return '""'
  }
  $escaped = $Value.Replace('\', '\\').Replace('"', '\"')
  return '"' + $escaped + '"'
}

function Add-NestedListEntry {
  param(
    [Parameter(Mandatory = $true)][string]$Text,
    [Parameter(Mandatory = $true)][string]$Section,
    [Parameter(Mandatory = $true)][string]$Entry
  )

  $emptyPattern = "(?m)^  $([regex]::Escape($Section)):\s*\[\]\s*$"
  if ($Text -match $emptyPattern) {
    return [regex]::Replace($Text, $emptyPattern, "  ${Section}:`r`n$Entry", 1)
  }

  $blockPattern = "(?ms)(^  $([regex]::Escape($Section)):\s*\r?\n)(?<body>.*?)(?=^  \S|\z)"
  if ($Text -match $blockPattern) {
    return [regex]::Replace($Text, $blockPattern, {
      param($match)
      $body = $match.Groups['body'].Value.TrimEnd()
      if ([string]::IsNullOrWhiteSpace($body)) {
        return $match.Groups[1].Value + $Entry + "`r`n"
      }
      return $match.Groups[1].Value + $body + "`r`n" + $Entry + "`r`n"
    })
  }

  return $Text.TrimEnd() + "`r`n  ${Section}:`r`n" + $Entry + "`r`n"
}

function Add-TopLevelListEntry {
  param(
    [Parameter(Mandatory = $true)][string]$Text,
    [Parameter(Mandatory = $true)][string]$Section,
    [Parameter(Mandatory = $true)][string]$Entry
  )

  if ([string]::IsNullOrWhiteSpace($Text)) {
    return "${Section}:`r`n$Entry`r`n"
  }

  $emptyPattern = "(?m)^$([regex]::Escape($Section)):\s*\[\]\s*$"
  if ($Text -match $emptyPattern) {
    return [regex]::Replace($Text, $emptyPattern, "${Section}:`r`n$Entry", 1)
  }

  $blockPattern = "(?ms)(^$([regex]::Escape($Section)):\s*\r?\n)(?<body>.*?)(?=^[A-Za-z_][A-Za-z0-9_-]*:|\z)"
  if ($Text -match $blockPattern) {
    return [regex]::Replace($Text, $blockPattern, {
      param($match)
      $body = $match.Groups['body'].Value.TrimEnd()
      if ([string]::IsNullOrWhiteSpace($body)) {
        return $match.Groups[1].Value + $Entry + "`r`n"
      }
      return $match.Groups[1].Value + $body + "`r`n" + $Entry + "`r`n"
    })
  }

  return $Text.TrimEnd() + "`r`n`r`n${Section}:`r`n" + $Entry + "`r`n"
}

function New-AuthorityEntry {
  param(
    [Parameter(Mandatory = $true)][string]$Artifact,
    [Parameter(Mandatory = $true)][string]$Status,
    [Parameter(Mandatory = $true)][string]$CloseoutId,
    [Parameter(Mandatory = $true)][string]$RecordedAt,
    [string]$Note = ''
  )

  return @"
    - artifact: $(Convert-ToYamlScalar $Artifact)
      status: $(Convert-ToYamlScalar $Status)
      closeout_id: $(Convert-ToYamlScalar $CloseoutId)
      reason: $(Convert-ToYamlScalar $Reason)
      recorded_at: $(Convert-ToYamlScalar $RecordedAt)
      note: $(Convert-ToYamlScalar $Note)
"@
}

function Get-DefaultAuthorityIndex {
  return @'
authority_index:
  version: 1
  purpose: "Canonical ledger for which workflow artifacts are active authority, evidence, superseded, promoted, or archived."
  source_of_truth:
    - ".workflow/current.yaml"
    - ".workflow/task.yaml"
    - ".workflow/open_threads.yaml"
    - ".workflow/verification.yaml"
    - ".workflow/thread_registry.yaml"
    - ".workflow/memory_points.yaml"
  current_authority: []
  active_evidence: []
  superseded: []
  promoted: []
  archived: []
  closeout_updates: []
  rules:
    - "Docs/plans/index.yaml may mirror this ledger, but .workflow/authority_index.yaml is the runtime authority source."
    - "Do not leave old plans equally active after a route, gate, or direction change."
    - "Promote stable lessons to Maestro spec/knowhow instead of growing workflow files forever."
    - "Archived receipts need restore or trace pointers."
'@
}

if (-not (Test-Path -LiteralPath $ProjectPath -PathType Container)) {
  throw "ProjectPath does not exist or is not a directory: $ProjectPath"
}

$project = (Resolve-Path -LiteralPath $ProjectPath).Path
$workflow = Join-Path $project '.workflow'
if (-not (Test-Path -LiteralPath $workflow -PathType Container)) {
  throw "Project does not have a .workflow directory. Run init-agents.ps1 -Mode auto first."
}

$stamp = Get-Date -Format 'yyyyMMdd-HHmmss'
$recordedAt = Get-Date -Format s
$closeoutId = "workflow_closeout_$stamp"
if ([string]::IsNullOrWhiteSpace($VerificationId)) {
  $VerificationId = "verification_$closeoutId"
}

$closeoutDir = Join-Path $workflow 'closeouts'
$receiptPath = Join-Path $closeoutDir "workflow-closeout-$stamp.yaml"
$receiptRel = ".workflow/closeouts/workflow-closeout-$stamp.yaml"
$authorityPath = Join-Path $workflow 'authority_index.yaml'
$verificationPath = Join-Path $workflow 'verification.yaml'
$currentPath = Join-Path $workflow 'current.yaml'
$sessionRecoveryPath = Join-Path $workflow 'session-recovery-brief.md'

$updated = New-Object System.Collections.Generic.List[string]
$planned = New-Object System.Collections.Generic.List[string]

$currentHeadStatus = 'unchanged'
$currentBeforeText = Read-TextOrEmpty $currentPath
if ($currentBeforeText -match '(?m)^updated_at:\s*.*$') {
  $currentHeadStatus = 'updated'
}

$headMutationsText = @"
  head_mutations:
    current:
      status: $currentHeadStatus
      note: "updated_at timestamp is refreshed when present"
    task:
      status: unchanged
      note: "closeout-workflow records the closeout but does not mutate task.yaml"
    open_threads:
      status: unchanged
      note: "closeout-workflow records thread refs but does not mutate open_threads.yaml"
    verification:
      status: updated
      note: "appends closeout verification evidence"
    authority_index:
      status: updated
      note: "records authority/evidence/supersession/promotion/archive refs"
    memory_points:
      status: unchanged
      note: "memory point ids are recorded only; memory_points.yaml is not mutated"
    thread_registry:
      status: unchanged
      note: "thread/delegate lifecycle records are not mutated by this closeout"
    session_recovery:
      status: updated
      note: "save-state refreshes session-recovery-brief.md after source files update"
"@

$updatedHeads = @()
if ($currentHeadStatus -eq 'updated') {
  $updatedHeads += '.workflow/current.yaml'
}
$updatedHeads += '.workflow/authority_index.yaml'
$updatedHeads += '.workflow/verification.yaml'
$updatedHeads += '.workflow/session-recovery-brief.md'
$updatedHeadsYaml = ($updatedHeads | ForEach-Object { "    - `"$($_)`"" }) -join "`r`n"

$receiptText = @"
workflow_closeout_receipt:
  id: $(Convert-ToYamlScalar $closeoutId)
  recorded_at: $(Convert-ToYamlScalar $recordedAt)
  reason: $(Convert-ToYamlScalar $Reason)
  task_id: $(Convert-ToYamlScalar $TaskId)
  route:
    from: $(Convert-ToYamlScalar $FromRoute)
    to: $(Convert-ToYamlScalar $ToRoute)
  active_head_before:
    current: ".workflow/current.yaml"
    task: ".workflow/task.yaml"
    open_threads: ".workflow/open_threads.yaml"
    verification: ".workflow/verification.yaml"
    authority_index: ".workflow/authority_index.yaml"
  active_head_after:
    current: ".workflow/current.yaml"
    task: ".workflow/task.yaml"
    open_threads: ".workflow/open_threads.yaml"
    verification: ".workflow/verification.yaml"
    authority_index: ".workflow/authority_index.yaml"
$headMutationsText
  updated_heads:
$updatedHeadsYaml
  closed_or_superseded_threads:
    - $(Convert-ToYamlScalar $OpenThreadId)
  authority_index_updates:
    current_authority:
      - $(Convert-ToYamlScalar $CurrentAuthority)
    active_evidence:
      - $(Convert-ToYamlScalar $receiptRel)
    superseded:
      - $(Convert-ToYamlScalar $SupersededArtifact)
    promoted:
      - $(Convert-ToYamlScalar $PromotedSpec)
      - $(Convert-ToYamlScalar $PromotedKnowhow)
    archived:
      - $(Convert-ToYamlScalar $ArchiveRef)
  maestro_promotions:
    spec:
      - $(Convert-ToYamlScalar $PromotedSpec)
    knowhow:
      - $(Convert-ToYamlScalar $PromotedKnowhow)
    kg_or_search_index: []
  memory_point:
    id: $(Convert-ToYamlScalar $MemoryPointId)
  session_recovery_update:
    status: $(if ($DryRun) { '"dry_run"' } else { '"refreshed"' })
    path: ".workflow/session-recovery-brief.md"
  validation_status:
    command: "validate-workflow.ps1 -ProjectPath <project>"
    status: not_run
  proves:
    - "A main-agent lifecycle closeout transaction was recorded."
  does_not_prove:
    - "This is not product acceptance."
    - "This is not UI/sample/generated-image/business acceptance."
    - "This is not proof that Maestro promotion or archive cleanup happened unless artifacts are listed."
  next_action: "Run validate-workflow.ps1, then continue from current.yaml/task.yaml authority."
"@

$planned.Add($receiptRel)
if ($currentHeadStatus -eq 'updated') {
  $planned.Add('.workflow/current.yaml')
}
$planned.Add('.workflow/authority_index.yaml')
$planned.Add('.workflow/verification.yaml')
$planned.Add('.workflow/session-recovery-brief.md')

if (-not $DryRun) {
  if (-not (Test-Path -LiteralPath $closeoutDir -PathType Container)) {
    New-Item -ItemType Directory -Path $closeoutDir -Force | Out-Null
  }
  Write-Utf8NoBom -Path $receiptPath -Text $receiptText
  $updated.Add($receiptRel)

  $authorityText = Read-TextOrEmpty $authorityPath
  if ([string]::IsNullOrWhiteSpace($authorityText)) {
    $authorityText = Get-DefaultAuthorityIndex
  }

  $authorityText = Add-NestedListEntry -Text $authorityText -Section 'active_evidence' -Entry (New-AuthorityEntry -Artifact $receiptRel -Status 'active_evidence' -CloseoutId $closeoutId -RecordedAt $recordedAt -Note 'workflow closeout receipt')
  $authorityText = Add-NestedListEntry -Text $authorityText -Section 'closeout_updates' -Entry (New-AuthorityEntry -Artifact $receiptRel -Status 'closeout' -CloseoutId $closeoutId -RecordedAt $recordedAt -Note 'lifecycle closeout transaction')

  if (-not [string]::IsNullOrWhiteSpace($CurrentAuthority)) {
    $authorityText = Add-NestedListEntry -Text $authorityText -Section 'current_authority' -Entry (New-AuthorityEntry -Artifact $CurrentAuthority -Status 'current' -CloseoutId $closeoutId -RecordedAt $recordedAt -Note 'marked current by closeout-workflow')
  }
  if (-not [string]::IsNullOrWhiteSpace($SupersededArtifact)) {
    $authorityText = Add-NestedListEntry -Text $authorityText -Section 'superseded' -Entry (New-AuthorityEntry -Artifact $SupersededArtifact -Status 'superseded' -CloseoutId $closeoutId -RecordedAt $recordedAt -Note 'superseded by main-agent closeout')
  }
  if (-not [string]::IsNullOrWhiteSpace($PromotedSpec)) {
    $authorityText = Add-NestedListEntry -Text $authorityText -Section 'promoted' -Entry (New-AuthorityEntry -Artifact $PromotedSpec -Status 'promoted_to_maestro_spec' -CloseoutId $closeoutId -RecordedAt $recordedAt -Note 'promotion reference recorded; verify Maestro write separately')
  }
  if (-not [string]::IsNullOrWhiteSpace($PromotedKnowhow)) {
    $authorityText = Add-NestedListEntry -Text $authorityText -Section 'promoted' -Entry (New-AuthorityEntry -Artifact $PromotedKnowhow -Status 'promoted_to_maestro_knowhow' -CloseoutId $closeoutId -RecordedAt $recordedAt -Note 'promotion reference recorded; verify Maestro write separately')
  }
  if (-not [string]::IsNullOrWhiteSpace($ArchiveRef)) {
    $authorityText = Add-NestedListEntry -Text $authorityText -Section 'archived' -Entry (New-AuthorityEntry -Artifact $ArchiveRef -Status 'archived' -CloseoutId $closeoutId -RecordedAt $recordedAt -Note 'archive or restore pointer recorded')
  }
  Write-Utf8NoBom -Path $authorityPath -Text $authorityText
  $updated.Add('.workflow/authority_index.yaml')

  $verificationEntry = @"
  - id: $(Convert-ToYamlScalar $VerificationId)
    task_id: $(Convert-ToYamlScalar $TaskId)
    status: "recorded_closeout_transaction_not_product_acceptance"
    commands_run:
      - "closeout-workflow.ps1 -Reason $Reason"
    browser_or_visual_evidence: []
    proves:
      - "A workflow closeout receipt was recorded at $receiptRel."
      - "authority_index.yaml and verification.yaml were updated."
    does_not_prove:
      - "This is not product acceptance."
      - "This does not prove UI/sample/generated-image/business acceptance."
      - "This does not prove Maestro spec/knowhow promotion unless separate Maestro evidence exists."
    risks:
      - "Text-based YAML updates may need human review in heavily customized workflow files."
    next_verification:
      - "Run validate-workflow.ps1 for the project."
"@
  $verificationText = Read-TextOrEmpty $verificationPath
  $verificationText = Add-TopLevelListEntry -Text $verificationText -Section 'verification_log' -Entry $verificationEntry
  Write-Utf8NoBom -Path $verificationPath -Text $verificationText
  $updated.Add('.workflow/verification.yaml')

  if (Test-Path -LiteralPath $currentPath -PathType Leaf) {
    $currentText = Get-Content -Raw -Encoding UTF8 -LiteralPath $currentPath
    $newCurrentText = [regex]::Replace($currentText, '(?m)^updated_at:\s*.*$', "updated_at: `"$recordedAt`"")
    if ($newCurrentText -ne $currentText) {
      Write-Utf8NoBom -Path $currentPath -Text $newCurrentText
      $updated.Add('.workflow/current.yaml')
    }
  }

  $saveScript = Join-Path $PSScriptRoot 'save-state.ps1'
  if (Test-Path -LiteralPath $saveScript -PathType Leaf) {
    & $saveScript -ProjectPath $project -Json | Out-Null
    $updated.Add('.workflow/session-recovery-brief.md')
  }
}

$result = [ordered]@{
  project = $project
  closeout_id = $closeoutId
  reason = $Reason
  dry_run = [bool]$DryRun
  receipt = $receiptRel
  planned_updates = $planned
  updated = $updated
  proof_boundary = 'recorded lifecycle closeout; not product acceptance'
  next_verification = 'Run validate-workflow.ps1 for this project.'
}

if ($Json) {
  $result | ConvertTo-Json -Depth 8
} else {
  Write-Output "Workflow closeout recorded: $closeoutId"
  Write-Output "Receipt: $receiptRel"
  Write-Output "Proof boundary: recorded lifecycle closeout; not product acceptance"
}
