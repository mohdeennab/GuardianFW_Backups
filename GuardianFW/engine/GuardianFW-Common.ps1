Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$global:GFRoot   = "C:\ProgramData\GuardianFW"
$global:GFPolicy = Join-Path $GFRoot "policy\active-policy.json"
$global:GFStateD = Join-Path $GFRoot "state"
$global:GFLogs   = Join-Path $GFRoot "logs"
$global:GFLockD  = Join-Path $GFRoot "lock"

$global:GFStateCurrent  = Join-Path $GFStateD "current_state.json"
$global:GFStateLastGood = Join-Path $GFStateD "last_good_state.json"
$global:GFCounters      = Join-Path $GFStateD "counters.json"

$global:GFLogGuardian = Join-Path $GFLogs "guardian.log"
$global:GFLogAutoHeal = Join-Path $GFLogs "autoheal.log"
$global:GFLogTamper   = Join-Path $GFLogs "tamper.log"
$global:GFLogEvidence = Join-Path $GFLogs "evidence.log"

function Ensure-GFDirs {
  $dirs = @(
    $GFRoot,
    (Join-Path $GFRoot "policy"),
    $GFStateD,
    $GFLogs,
    $GFLockD
  )
  foreach ($d in $dirs) { if (!(Test-Path $d)) { New-Item -ItemType Directory -Path $d -Force | Out-Null } }
}

function Write-GFLog {
  param(
    [Parameter(Mandatory)] [string] $Path,
    [Parameter(Mandatory)] [string] $Message,
    [ValidateSet("INFO","WARN","ERR","SEC")] [string] $Level="INFO"
  )
  Ensure-GFDirs
  $ts = (Get-Date).ToUniversalTime().ToString("s") + "Z"
  $line = "[$ts][$Level] $Message"
  Add-Content -LiteralPath $Path -Value $line -Encoding UTF8 -Force
}

function Read-JsonFile {
  param([Parameter(Mandatory)] [string] $Path, [object] $Default = $null)
  try {
    if (!(Test-Path $Path)) { return $Default }
    $raw = Get-Content -LiteralPath $Path -Raw -Encoding UTF8
    if ([string]::IsNullOrWhiteSpace($raw)) { return $Default }
    return ($raw | ConvertFrom-Json -ErrorAction Stop)
  } catch { return $Default }
}

function Write-JsonFile {
  param([Parameter(Mandatory)] [string] $Path, [Parameter(Mandatory)] [object] $Obj)
  Ensure-GFDirs
  ($Obj | ConvertTo-Json -Depth 10) | Set-Content -LiteralPath $Path -Encoding UTF8 -Force
}

function Get-UTCIso { (Get-Date).ToUniversalTime().ToString("s") + "Z" }
