# GuardianFW Test Script
# Run this to test your installation

Write-Host "=========================================" -ForegroundColor Cyan
Write-Host "     GUARDIANFW INSTALLATION TEST" -ForegroundColor Cyan
Write-Host "=========================================" -ForegroundColor Cyan

# Import logging module
. "C:\GuardianFW\scripts\log_functions.ps1"

Write-GuardianLog -Message "Starting GuardianFW installation test" -Level Info -Component "Test"

# Test 1: Check directories
Write-Host "`n[TEST 1] Checking directory structure..." -ForegroundColor Yellow
$directories = @(
    "C:\GuardianFW",
    "C:\GuardianFW\config",
    "C:\GuardianFW\logs",
    "C:\GuardianFW\scripts",
    "C:\GuardianFW\secure"
)

$allExist = $true
foreach ($dir in $directories) {
    if (Test-Path $dir) {
        Write-Host "   $dir" -ForegroundColor Green
    } else {
        Write-Host "   $dir (MISSING)" -ForegroundColor Red
        $allExist = $false
    }
}

# Test 2: Check configuration files
Write-Host "`n[TEST 2] Checking configuration files..." -ForegroundColor Yellow
$configFiles = @(
    "C:\GuardianFW\config\settings.json",
    "C:\GuardianFW\secure\splunk_token.xml"
)

foreach ($file in $configFiles) {
    if (Test-Path $file) {
        $size = (Get-Item $file).Length
        Write-Host "   $file ($size bytes)" -ForegroundColor Green
    } else {
        Write-Host "   $file (MISSING)" -ForegroundColor Red
        $allExist = $false
    }
}

# Test 3: Check scripts
Write-Host "`n[TEST 3] Checking script files..." -ForegroundColor Yellow
$scriptFiles = @(
    "C:\GuardianFW\scripts\log_functions.ps1",
    "C:\GuardianFW\scripts\monitor.ps1"
)

foreach ($script in $scriptFiles) {
    if (Test-Path $script) {
        $lines = (Get-Content $script).Length
        Write-Host "   $script ($lines lines)" -ForegroundColor Green
    } else {
        Write-Host "   $script (MISSING)" -ForegroundColor Red
        $allExist = $false
    }
}

# Test 4: Test logging
Write-Host "`n[TEST 4] Testing logging system..." -ForegroundColor Yellow
try {
    Write-GuardianLog -Message "This is a test log message" -Level Info -Component "Test"
    Write-GuardianLog -Message "This is a warning test" -Level Warning -Component "Test"
    Write-GuardianLog -Message "This is an error test" -Level Error -Component "Test"
    
    # Check if log file was created
    $logFile = "C:\GuardianFW\logs\$(Get-Date -Format 'yyyy-MM-dd').log"
    if (Test-Path $logFile) {
        $logCount = (Get-Content $logFile).Length
        Write-Host "   Log file created: $logFile ($logCount entries)" -ForegroundColor Green
    } else {
        Write-Host "   Log file not created" -ForegroundColor Red
        $allExist = $false
    }
} catch {
    Write-Host "   Logging test failed: $_" -ForegroundColor Red
    $allExist = $false
}

# Summary
Write-Host "`n=========================================" -ForegroundColor Cyan
Write-Host "     TEST SUMMARY" -ForegroundColor Cyan
Write-Host "=========================================" -ForegroundColor Cyan

if ($allExist) {
    Write-Host "[SUCCESS] All tests passed! GuardianFW is ready." -ForegroundColor Green
    Write-Host "`nNext steps:" -ForegroundColor Yellow
    Write-Host "1. Review configuration: C:\GuardianFW\config\settings.json"
    Write-Host "2. Update Splunk URL and token in settings if needed"
    Write-Host "3. Run the monitor: powershell -File `"C:\GuardianFW\scripts\monitor.ps1`""
    Write-Host "4. Check logs: Get-Content C:\GuardianFW\logs\*.log | ConvertFrom-Json"
} else {
    Write-Host "[WARNING] Some tests failed. Review the issues above." -ForegroundColor Yellow
}

Write-GuardianLog -Message "GuardianFW test completed" -Level Info -Component "Test"
