# C:\ProgramData\GuardianFW\engine\write-decision-heartbeat.ps1
# Writes/refreshes a "latest decision" JSON with a fresh timestamp (heartbeat).
# Safe for schedulers: atomic write + tolerant if folders missing.

param(
  [string]$DecisionPath = "C:\ProgramData\GuardianFW\evidence\decision\decision-latest.json",
  [string]$Mode = "prod",
  [string]$Status = "OK",
  [string]$Note = "heartbeat"
)

$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest

function Ensure-Dir([string]$p){
  $dir = Split-Path -Parent $p
  if($dir -and -not (Test-Path -LiteralPath $dir)){
    New-Item -ItemType Directory -Path $dir -Force | Out-Null
  }
}

function Atomic-WriteJson([string]$path, [object]$obj){
  Ensure-Dir $path
  $tmp = "$path.tmp_{0}" -f ([guid]::NewGuid().ToString("N"))
  $json = $obj | ConvertTo-Json -Depth 30 -Compress
  [System.IO.File]::WriteAllText($tmp, $json, [System.Text.Encoding]::UTF8)
  Move-Item -LiteralPath $tmp -Destination $path -Force
}

$existing = $null
if(Test-Path -LiteralPath $DecisionPath){
  try { $existing = Get-Content -LiteralPath $DecisionPath -Raw -Encoding UTF8 | ConvertFrom-Json } catch { $existing = $null }
}

$now = (Get-Date).ToString("o")

$out = [ordered]@{}
if($existing){
  $existing.PSObject.Properties | ForEach-Object { $out[$_.Name] = $_.Value }
}

$out["timestamp"] = $now
$out["mode"]      = $Mode
$out["status"]    = $Status
$out["note"]      = $Note

Atomic-WriteJson -path $DecisionPath -obj $out
exit 0
