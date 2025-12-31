$ErrorActionPreference="SilentlyContinue"

$Base = "C:\GuardianFW\GuardianDNS"
$Py   = Join-Path $Base "guardian_dns.py"
$out  = Join-Path $Base "guardian.out.log"
$err  = Join-Path $Base "guardian.err.log"

# Pick active adapter (Wi-Fi preferred)
$ifx = (Get-NetAdapter | Where-Object { $_.Status -eq "Up" -and $_.Name -eq "Wi-Fi" } | Select-Object -First 1).InterfaceIndex
if(-not $ifx){
  $ifx = (Get-NetIPConfiguration | Where-Object { $_.IPv4DefaultGateway -ne $null } | Select-Object -First 1).InterfaceIndex
}
if(-not $ifx){ exit 0 }

# Kill any old guardian_dns.py
Get-CimInstance Win32_Process |
  Where-Object { $_.CommandLine -match "guardian_dns\.py" } |
  ForEach-Object { Stop-Process -Id $_.ProcessId -Force -ErrorAction SilentlyContinue }

Start-Sleep 1

# Start GuardianDNS (redirect logs)
Start-Process -FilePath "python.exe" `
  -ArgumentList "`"$Py`"" `
  -WorkingDirectory $Base `
  -WindowStyle Hidden `
  -RedirectStandardOutput $out `
  -RedirectStandardError  $err

Start-Sleep 1

# Set DNS (keep fallback to avoid outages)
Set-DnsClientServerAddress -InterfaceIndex $ifx -ServerAddresses @("127.0.0.1","1.1.1.1")

ipconfig /flushdns | Out-Null
Clear-DnsClientCache
