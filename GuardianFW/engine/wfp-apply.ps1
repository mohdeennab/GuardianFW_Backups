# GuardianFW WFP apply wrapper (StrictMode-safe)
# - targets.domains is OPTIONAL
# - if no targets => log + exit 0 (safe default)
# - runs DeepBlockRunner/DeepUnblockRunner with -Domain to avoid prompts

Set-StrictMode -Version Latest
$ErrorActionPreference="Stop"

$pol = "C:\ProgramData\GuardianFW\policy\active-policy.json"
$p = Get-Content $pol -Raw -Encoding UTF8 | ConvertFrom-Json

$ev = "C:\ProgramData\GuardianFW\logs\evidence.log"

$deepBlock   = "C:\Users\mohde\Documents\firewallP\tools\DeepBlockRunner.ps1"
$deepUnblock = "C:\Users\mohde\Documents\firewallP\tools\DeepUnblockRunner.ps1"
$clearAll    = "C:\Users\mohde\Documents\firewallP\tools\FirewallClearAll.ps1"

function Get-UTCIso { (Get-Date).ToUniversalTime().ToString("s") + "Z" }
function Ev([string]$msg){
  $line = "[{0}][INFO] {1}" -f (Get-UTCIso), $msg
  Add-Content -LiteralPath $ev -Value $line -Encoding UTF8 -Force
}

function Get-TargetDomains {
  param($Policy)
  try {
    if ($Policy.targets -and $Policy.targets.domains -and $Policy.targets.domains.Count -gt 0) {
      return @(
        $Policy.targets.domains |
          ForEach-Object { [string]$_ } |
          Where-Object { $_ -and $_.Trim() }
      )
    }
  } catch {}
  return @()   # SAFE DEFAULT: no targets
}

try {
  # mode (compute once)
  $lockdown = $true
  if ($p.network -and ($p.network.allow_loopback_only -ne $null)) {
    $lockdown = [bool]$p.network.allow_loopback_only
  }
  $mode = $(if($lockdown){"lockdown"}else{"relax"})

  # targets
  $domains = Get-TargetDomains -Policy $p

  if (-not $domains -or $domains.Count -eq 0) {
    Ev "[WFP] mode=$mode targets=none (skipped)"
    exit 0
  }

  $domCsv = ($domains -join ",")

  if ($lockdown) {
    if (!(Test-Path $deepBlock)) { Write-Host "Missing: $deepBlock"; exit 41 }
    Ev "[WFP] mode=$mode domains=$domCsv tool=$(Split-Path $deepBlock -Leaf)"
    foreach($d in $domains){
      & $deepBlock -Domain $d
      if($LASTEXITCODE -ne 0){ exit $LASTEXITCODE }
    }
    exit 0
  } else {
    if (Test-Path $deepUnblock) {
      Ev "[WFP] mode=$mode domains=$domCsv tool=$(Split-Path $deepUnblock -Leaf)"
      foreach($d in $domains){
        & $deepUnblock -Domain $d
        if($LASTEXITCODE -ne 0){ exit $LASTEXITCODE }
      }
      exit 0
    }

    if (Test-Path $clearAll) {
      Ev "[WFP] mode=$mode domains=$domCsv tool=$(Split-Path $clearAll -Leaf)"
      & $clearAll
      exit $LASTEXITCODE
    }

    Write-Host "Missing: $deepUnblock AND $clearAll"
    exit 42
  }
} catch {
  Write-Host $_.Exception.Message
  exit 50
}
