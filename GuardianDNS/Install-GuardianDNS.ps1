#Requires -RunAsAdministrator
Set-StrictMode -Version Latest
$ErrorActionPreference="Stop"

$Base="C:\GuardianFW\GuardianDNS"
$Py="$Base\guardian_dns.py"
$List="$Base\blocked-domains.json"
$BackupDir="$Base\backup\$(Get-Date -Format 'yyyyMMdd-HHmmss')"
$PrimaryDNS="127.0.0.1"
$FallbackDNS="192.168.4.1"

if(!(Test-Path $Py)){ throw "Missing $Py" }
if(!(Test-Path $List)){ throw "Missing $List" }

New-Item -ItemType Directory -Force -Path $BackupDir | Out-Null

# Backup DNS config
$dnsBackup="$BackupDir\dns-backup.json"
Get-DnsClientServerAddress -AddressFamily IPv4 |
  Select-Object InterfaceAlias, InterfaceIndex, ServerAddresses |
  ConvertTo-Json -Depth 5 | Set-Content -Encoding UTF8 $dnsBackup

# Stop any old GuardianDNS python processes (optional safety)
Get-CimInstance Win32_Process |
  Where-Object { $_.CommandLine -match "guardian_dns\.py" } |
  ForEach-Object { Stop-Process -Id $_.ProcessId -Force -ErrorAction SilentlyContinue }

Start-Sleep -Seconds 1

Write-Host "Starting GuardianDNS..."
Start-Process -FilePath "py" -ArgumentList "`"$Py`"" -WorkingDirectory $Base

Start-Sleep -Seconds 2

# Set DNS on active adapters with FAIL-OPEN fallback
$adapters = Get-NetAdapter | Where-Object {$_.Status -eq "Up" -and $_.InterfaceAlias -match "Wi-Fi|Ethernet"}
foreach($a in $adapters){
  Set-DnsClientServerAddress -InterfaceIndex $a.InterfaceIndex -ServerAddresses @($PrimaryDNS,$FallbackDNS)
}

ipconfig /flushdns | Out-Null

Write-Host "GuardianDNS installed."
Write-Host "Backup saved at: $BackupDir"
Write-Host "DNS set to: $PrimaryDNS (primary), $FallbackDNS (fallback)"
Write-Host "Log: $Base\dns.log"
