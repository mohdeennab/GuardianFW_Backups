param(
  [int]$SleepSeconds = 2
)

"Stopping GuardianAgent..."
Stop-Service GuardianAgent -ErrorAction SilentlyContinue
Start-Sleep -Seconds $SleepSeconds

"Restarting GuardianControl..."
Restart-Service GuardianControl -ErrorAction Stop
Start-Sleep -Seconds $SleepSeconds

"Starting GuardianAgent..."
Start-Service GuardianAgent -ErrorAction Stop
Start-Sleep -Seconds $SleepSeconds

"OK: Restart complete."
Get-Service GuardianControl,GuardianAgent | Format-Table -AutoSize
