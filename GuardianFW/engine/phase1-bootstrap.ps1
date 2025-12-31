# phase1-bootstrap.ps1
# Creates folder contract, creates config.json if missing, and writes baseline hashes.
# Run as admin (or SYSTEM).

$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest

$Root = "C:\ProgramData\GuardianFW"
$Dirs = @("engine","policy","rules","evidence","logs","quarantine","baseline","tools")

foreach($d in $Dirs){
  $p = Join-Path $Root $d
  if(-not (Test-Path $p)){ New-Item -ItemType Directory -Path $p -Force | Out-Null }
}

# config.json (create only if missing)
$configPath = Join-Path $Root "config.json"
if(-not (Test-Path $configPath)){
  $config = @{
    version = 1
    health_interval_sec = 60
    enforcement = @{
      dns      = $true
      firewall = $false
      process  = $false
    }
    safe_fail = "allow"
  } | ConvertTo-Json -Depth 5
  $config | Set-Content -LiteralPath $configPath -Encoding UTF8
}

# Create modules if missing (safety)
$placeholders = @(
  (Join-Path $Root "engine\Guardian.ExitCodes.psm1"),
  (Join-Path $Root "engine\Guardian.Evidence.psm1"),
  (Join-Path $Root "engine\Guardian.Config.psm1"),
  (Join-Path $Root "engine\Guardian.DB.psm1")
)
foreach($ph in $placeholders){
  if(-not (Test-Path $ph)){
    "# placeholder - will be replaced" | Set-Content -LiteralPath $ph -Encoding UTF8
  }
}

# Baseline file list (Phase 1 core)
$BaselineFiles = @(
  (Join-Path $Root "config.json"),
  (Join-Path $Root "engine\run-health.ps1"),
  (Join-Path $Root "engine\Guardian.ExitCodes.psm1"),
  (Join-Path $Root "engine\Guardian.Evidence.psm1"),
  (Join-Path $Root "engine\Guardian.Config.psm1"),
  (Join-Path $Root "engine\Guardian.DB.psm1")
)

# Write baseline hashes
$baselineOut = Join-Path $Root "baseline\baseline.sha256"
"## GuardianFW baseline hashes (Phase1)" | Set-Content $baselineOut -Encoding UTF8

foreach($f in $BaselineFiles){
  if(Test-Path $f){
    $h = (Get-FileHash -Algorithm SHA256 -LiteralPath $f).Hash.ToLower()
    "{0} *{1}" -f $h, $f | Add-Content -LiteralPath $baselineOut -Encoding UTF8
  } else {
    "MISSING *$f" | Add-Content -LiteralPath $baselineOut -Encoding UTF8
  }
}

Write-Host "[OK] Phase1 folders + config + baseline hashes created:"
Write-Host "     $baselineOut"