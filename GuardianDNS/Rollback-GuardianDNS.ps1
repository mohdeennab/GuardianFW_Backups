#Requires -RunAsAdministrator
param(
  [Parameter(Mandatory=$true)]
  [string]$BackupDir
)

Set-StrictMode -Version Latest
$ErrorActionPreference="Stop"

$dnsBackup = Join-Path $BackupDir "dns-backup.json"
if(!(Test-Path $dnsBackup)){ throw "Backup not found: $dnsBackup" }

# Restore DNS
$state = Get-Content $dnsBackup -Raw | ConvertFrom-Json
foreach($row in $state){
  if(-not $row.ServerAddresses -or $row.ServerAddresses.Count -eq 0){
    Set-DnsClientServerAddress -InterfaceIndex $row.InterfaceIndex -ResetServerAddresses
  } else {
    Set-DnsClientServerAddress -InterfaceIndex $row.InterfaceIndex -ServerAddresses $row.ServerAddresses
  }
}

ipconfig /flushdns | Out-Null

# Stop GuardianDNS python
Get-CimInstance Win32_Process |
  Where-Object { $_.CommandLine -match "guardian_dns\.py" } |
  ForEach-Object { Stop-Process -Id $_.ProcessId -Force }

Write-Host "Rollback complete."
