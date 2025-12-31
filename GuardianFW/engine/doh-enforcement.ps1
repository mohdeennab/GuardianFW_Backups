# GuardianFW DoH enforcement wrapper (StrictMode-safe)
$ErrorActionPreference="Stop"

$pol = "C:\ProgramData\GuardianFW\policy\active-policy.json"
$p = Get-Content $pol -Raw -Encoding UTF8 | ConvertFrom-Json

$block   = "C:\Users\mohde\Documents\firewallP\tools\DoHBlock.ps1"
$unblock = "C:\Users\mohde\Documents\firewallP\tools\DoHUnblock.ps1"

function Get-ExitCodeOrZero {
  # Under StrictMode, $LASTEXITCODE may be unset
  try {
    if (Test-Path variable:LASTEXITCODE) { return [int]$LASTEXITCODE }
  } catch {}
  return 0
}

try {
  if ($p.dns -and $p.dns.block_doh -eq $true) {
    if (!(Test-Path $block)) { Write-Host "Missing: $block"; exit 21 }
    & $block
    exit (Get-ExitCodeOrZero)
  } else {
    if (!(Test-Path $unblock)) { Write-Host "Missing: $unblock"; exit 22 }
    & $unblock
    exit (Get-ExitCodeOrZero)
  }
} catch {
  Write-Host $_.Exception.Message
  exit 50
}
