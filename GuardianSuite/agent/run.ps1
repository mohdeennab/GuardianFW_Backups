param(
  [string]$Control = "http://127.0.0.1:5052",
  [string]$DeviceName = "Dad-Laptop",
  [string]$Profile = "Kids",
  [int]$Minutes = 30
)
$ErrorActionPreference="Stop"
$here = $PSScriptRoot
if(-not $here){ $here = (Get-Location).Path }
Set-Location $here
& ".\.venv\Scripts\Activate.ps1"

$env:GUARDIAN_CONTROL = $Control
$env:GUARDIAN_DEVICE_NAME = $DeviceName

# --- Preflight: Control API must be reachable ---
try {
  $h = irm -Method Get "$Control/health" -TimeoutSec 2
  Write-Host ("Control health: " + ($h | ConvertTo-Json -Compress))
} catch {
  Write-Host ("[ERROR] Control not reachable at: " + $Control) -ForegroundColor Red
  Write-Host ("        Try: curl.exe " + $Control + "/health") -ForegroundColor Yellow
  throw
}
# Create pairing code
$Control = $Control.Trim()
$pair = irm -Method Post "$Control/admin/pairing/create?profile=$Profile&minutes=$Minutes"
Write-Host ("Pairing code: " + $pair.pairing_code)
Set-Content -Path (Join-Path $here "last_pairing_code.txt") -Value $pair.pairing_code -Encoding ASCII
$env:GUARDIAN_PAIRING_CODE = $pair.pairing_code

python .\guardian_agent.py
