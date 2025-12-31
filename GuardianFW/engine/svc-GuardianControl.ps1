# ---- AUDIT_DEDUPE_ROOT ----
$Global:GuardianRoot = "C:\ProgramData\GuardianFW"
. "$Global:GuardianRoot\engine\audit-dedupe.ps1"

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$Root     = "C:\ProgramData\GuardianFW"
$stopFlag = Join-Path $Root "sealed\SERVICE_STOP.flag"
$lockDir  = Join-Path $Root "sealed"
$lockFile = Join-Path $lockDir "GuardianControl.lock"
$logFile  = Join-Path $Root "logs\guardian-service.log"
$src      = "C:\ProgramData\GuardianFW\engine\process-dns-enforce.ps1"

if(!(Test-Path $lockDir)){ New-Item -ItemType Directory -Path $lockDir -Force | Out-Null }

function Log([string]$m){
  try { Add-Content -LiteralPath $logFile -Value ("[{0}] [GuardianControl] {1}" -f (Get-Date).ToString("s"), $m) -Encoding UTF8 } catch {}
}

# Clear stop flag on start (important after manual stop)
Remove-Item -LiteralPath $stopFlag -Force -ErrorAction SilentlyContinue | Out-Null

# Single-instance lock
try {
  $fs = [System.IO.File]::Open($lockFile,[System.IO.FileMode]::OpenOrCreate,[System.IO.FileAccess]::ReadWrite,[System.IO.FileShare]::None)
} catch {
  Log "LOCKED: another instance is running. Exiting."
  exit 0
}

Log "START"

try {
  while(-not (Test-Path -LiteralPath $stopFlag)) {
    try {
      & "$src" | Out-Null
    } catch {
      Log ("Loop error: " + ($_ | Out-String))
    }
    Start-Sleep -Seconds 5
  }
  Log "STOP flag detected. Exiting loop."
} finally {
  try { $fs.Dispose() } catch {}
  try { Remove-Item -LiteralPath $lockFile -Force -ErrorAction SilentlyContinue | Out-Null } catch {}
  Log "EXIT"
}


# ---- WRITE-AUDIT OVERRIDE (DEDUPE ENFORCED) ----
if(Get-Command Write-Audit -ErrorAction SilentlyContinue){
  Remove-Item function:Write-Audit -Force
}

function Write-Audit([string]$event,[hashtable]$data=@{}){
  try {
    if(-not (Should-LogEvent -Root $Global:GuardianRoot -ev $event -data $data)){
      return
    }
  } catch {
    # fail-secure: continue logging
  }

  $rec = @{
    tsUtc = [DateTime]::UtcNow.ToString("o")
    event = $event
    data  = $data
  }

  $log = Join-Path $Global:GuardianRoot "logs\guardian-audit.jsonl"
  ($rec | ConvertTo-Json -Compress -Depth 12) | Add-Content -LiteralPath $log -Encoding UTF8
}
