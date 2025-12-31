# Splunk Local Setup for GuardianFW Testing

Write-Host "=== Setting up Splunk for GuardianFW Testing ===" -ForegroundColor Cyan

# 1. Download Splunk (if not already installed)
$splunkPath = "C:\Splunk"
if (-not (Test-Path $splunkPath)) {
    Write-Host "Splunk not found. Would you like to download and install it? (Y/N)" -ForegroundColor Yellow
    $response = Read-Host
    if ($response -eq 'Y') {
        Write-Host "Please download Splunk from: https://www.splunk.com/en_us/download/splunk-enterprise.html" -ForegroundColor Yellow
        Write-Host "After installation, run this script again." -ForegroundColor Yellow
        pause
        exit
    }
}

# 2. Configure Splunk HEC (HTTP Event Collector)
Write-Host "`nConfiguring Splunk HEC..." -ForegroundColor Yellow

# Create HEC configuration
$hecConfig = @"
[http://localhost:8088]
disabled = 0
enableSSL = 1
sslVersions = tls1.2
sslRootCAPath = \$SPLUNK_HOME\etc\auth\cacert.pem
serverCert = \$SPLUNK_HOME\etc\auth\server.pem
sslPassword = 
outputGroup = hec_group
token = e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855
"@

$hecConfig | Out-File "$splunkPath\etc\apps\search\local\inputs.conf" -Force

# 3. Create GuardianFW index
$indexesConfig = @"
[guardianfw]
coldPath = \$SPLUNK_DB\guardianfw\colddb
homePath = \$SPLUNK_DB\guardianfw\db
thawedPath = \$SPLUNK_DB\guardianfw\thaweddb
"@

$indexesConfig | Out-File "$splunkPath\etc\apps\search\local\indexes.conf" -Force

# 4. Update GuardianFW configuration
$guardianConfig = @"
{
  "Splunk": {
    "Enabled": true,
    "Url": "https://localhost:8088",
    "TokenPath": "C:\\GuardianFW\\secure\\splunk_token.xml",
    "Index": "guardianfw",
    "SourceType": "guardianfw:logs"
  }
}
"@

$guardianConfig | ConvertFrom-Json | ForEach-Object {
    $config = Get-Content "C:\GuardianFW\config\settings.json" | ConvertFrom-Json
    $config.Splunk = $_.Splunk
    $config | ConvertTo-Json -Depth 5 | Out-File "C:\GuardianFW\config\settings.json" -Encoding UTF8 -Force
}

Write-Host "`nSplunk configuration completed!" -ForegroundColor Green
Write-Host "1. Start Splunk: C:\Splunk\bin\splunk.exe start" -ForegroundColor Gray
Write-Host "2. Login to Splunk web interface: https://localhost:8000" -ForegroundColor Gray
Write-Host "3. Default credentials: admin/changeme" -ForegroundColor Gray
Write-Host "4. Run GuardianFW: cd C:\GuardianFW\scripts; .\enhanced_monitor.ps1" -ForegroundColor Gray
