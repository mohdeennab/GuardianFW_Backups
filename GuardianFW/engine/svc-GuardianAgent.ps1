Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$Root     = "C:\ProgramData\GuardianFW"
$stopFlag = Join-Path $Root "sealed\SERVICE_STOP.flag"
$lockDir  = Join-Path $Root "sealed"
$lockFile = Join-Path $lockDir "GuardianAgent.lock"
$logFile  = Join-Path $Root "logs\guardian-service.log"
$cmd      = "C:\ProgramData\GuardianFW\engine\run-health-task.cmd"

if(!(Test-Path $lockDir)){ New-Item -ItemType Directory -Path $lockDir -Force | Out-Null }

function Log([string]$m){
  try { Add-Content -LiteralPath $logFile -Value ("[{0}] [GuardianAgent] {1}" -f (Get-Date).ToString("s"), $m) -Encoding UTF8 } catch {}
}

Remove-Item -LiteralPath $stopFlag -Force -ErrorAction SilentlyContinue | Out-Null

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
      cmd.exe /c "$cmd" | Out-Null
    } catch {
      Log ("Loop error: " + ($_ | Out-String))
    }
    Start-Sleep -Seconds 15
  }
  Log "STOP flag detected. Exiting loop."
} finally {
  try { $fs.Dispose() } catch {}
  try { Remove-Item -LiteralPath $lockFile -Force -ErrorAction SilentlyContinue | Out-Null } catch {}
  Log "EXIT"
}
