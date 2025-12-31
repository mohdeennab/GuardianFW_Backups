# Guardian.Evidence.psm1
Set-StrictMode -Version Latest

function New-GfwGuid { ([guid]::NewGuid().ToString()) }

function Get-GfwUtcIso {
  (Get-Date).ToUniversalTime().ToString("yyyy-MM-ddTHH:mm:ss.fffZ")
}

function Write-GfwEvidence {
  param(
    [Parameter(Mandatory)] [string]$Component,
    [Parameter(Mandatory)] [string]$Action,
    [Parameter(Mandatory)] [ValidateSet("OK","NOOP","DRIFT","FAIL","INVALID","TAMPER")] [string]$Result,
    [Parameter(Mandatory)] [int]$ExitCode,
    [string]$PolicyId = "",
    [int]$PolicyVersion = 0,
    [hashtable]$Details = @{},
    [string]$CorrelationId = ""
  )

  $root = "C:\ProgramData\GuardianFW"
  $evDir = Join-Path $root "evidence"
  if(-not (Test-Path $evDir)){ New-Item -ItemType Directory -Path $evDir -Force | Out-Null }

  if([string]::IsNullOrWhiteSpace($CorrelationId)){ $CorrelationId = New-GfwGuid }

  $obj = [ordered]@{
    event_id       = New-GfwGuid
    correlation_id = $CorrelationId
    timestamp      = Get-GfwUtcIso
    component      = $Component
    action         = $Action
    result         = $Result
    exit_code      = $ExitCode
    policy_id      = $PolicyId
    policy_version = $PolicyVersion
    details        = $Details
  }

  $line = ($obj | ConvertTo-Json -Depth 8 -Compress)
  $evPath = Join-Path $evDir "guardian.evidence.jsonl"
  Add-Content -LiteralPath $evPath -Value $line -Encoding UTF8

  return $CorrelationId
}

Export-ModuleMember -Function Write-GfwEvidence