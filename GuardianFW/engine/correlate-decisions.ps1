$ErrorActionPreference="Stop"
$root="C:\ProgramData\GuardianFW\evidence\decisions"

if(!(Test-Path $root)){
  @{ window="15m"; total_decisions=0; high_risk=0; intents=@() } | ConvertTo-Json -Depth 6
  exit 0
}

# Force array with @()
$events = @(
  Get-ChildItem $root -Filter *.json -File |
    Where-Object { $_.LastWriteTime -gt (Get-Date).AddMinutes(-15) } |
    ForEach-Object {
      try { Get-Content $_.FullName -Raw | ConvertFrom-Json } catch {}
    } | Where-Object { $_ -and $_.intent_id }
)

$summary = @{
  window = "15m"
  total_decisions = $events.Count
  high_risk = (@($events | Where-Object { $_.risk_score -ge 70 })).Count
  intents = @($events | Group-Object intent_id | Select-Object Name,Count)
}

$summary | ConvertTo-Json -Depth 6
