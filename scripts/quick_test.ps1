# GuardianFW Quick Test
Write-Host "=== GUARDIANFW QUICK TEST ===" -ForegroundColor Cyan

# Test 1: Check scripts
Write-Host "`n[TEST 1] Checking scripts..." -ForegroundColor Yellow
$scripts = @(
    "C:\GuardianFW\scripts\log_functions.ps1",
    "C:\GuardianFW\scripts\dashboard.ps1",
    "C:\GuardianFW\scripts\enhanced_monitor.ps1"
)

foreach ($script in $scripts) {
    if (Test-Path $script) {
        Write-Host "   $script" -ForegroundColor Green
    } else {
        Write-Host "   $script" -ForegroundColor Red
    }
}

# Test 2: Test Get-SystemHealth function
Write-Host "`n[TEST 2] Testing system health function..." -ForegroundColor Yellow
try {
    # Define the function
    function Get-SystemHealth {
        $health = @{
            Timestamp = Get-Date -Format "o"
            CPU = (Get-Counter '\Processor(_Total)\% Processor Time' -ErrorAction SilentlyContinue).CounterSamples.CookedValue
            Memory = (Get-Counter '\Memory\% Committed Bytes In Use' -ErrorAction SilentlyContinue).CounterSamples.CookedValue
            Disk = (Get-PSDrive C | Select-Object @{Name='FreeGB';Expression={[math]::Round($_.Free/1GB,2)}}, @{Name='UsedGB';Expression={[math]::Round($_.Used/1GB,2)}})
            Processes = (Get-Process).Count
            Threads = (Get-Process | ForEach-Object { $_.Threads.Count } | Measure-Object -Sum).Sum
            Uptime = [math]::Round((New-TimeSpan -Start (Get-CimInstance Win32_OperatingSystem).LastBootUpTime -End (Get-Date)).TotalHours, 2)
        }
        return $health
    }
    
    $health = Get-SystemHealth
    Write-Host "   System health check successful" -ForegroundColor Green
    Write-Host "    CPU: $([math]::Round($health.CPU, 1))%" -ForegroundColor Gray
    Write-Host "    Memory: $([math]::Round($health.Memory, 1))%" -ForegroundColor Gray
    Write-Host "    Processes: $($health.Processes)" -ForegroundColor Gray
    Write-Host "    Threads: $($health.Threads)" -ForegroundColor Gray
    Write-Host "    Uptime: $($health.Uptime) hours" -ForegroundColor Gray
    
} catch {
    Write-Host "   System health test failed: $_" -ForegroundColor Red
}

# Test 3: Check log file
Write-Host "`n[TEST 3] Checking logs..." -ForegroundColor Yellow
$todayLog = "C:\GuardianFW\logs\$(Get-Date -Format 'yyyy-MM-dd').log"
if (Test-Path $todayLog) {
    $entries = (Get-Content $todayLog | Where-Object { -not [string]::IsNullOrWhiteSpace($_) }).Count
    Write-Host "   Log file exists: $todayLog ($entries entries)" -ForegroundColor Green
} else {
    Write-Host "   No log file for today" -ForegroundColor Yellow
}

# Test 4: Check queue
Write-Host "`n[TEST 4] Checking queue..." -ForegroundColor Yellow
$queueFiles = Get-ChildItem "C:\GuardianFW\queue\*.json" -ErrorAction SilentlyContinue
if ($queueFiles) {
    Write-Host "  Queue has $($queueFiles.Count) pending files" -ForegroundColor Yellow
} else {
    Write-Host "   Queue is empty" -ForegroundColor Green
}

# Test 5: Check GuardianFW service
Write-Host "`n[TEST 5] Checking GuardianFW service..." -ForegroundColor Yellow
$service = Get-Service -Name "GuardianFW" -ErrorAction SilentlyContinue
if ($service) {
    Write-Host "  Service status: $($service.Status)" -ForegroundColor $(if ($service.Status -eq 'Running') { 'Green' } else { 'Yellow' })
} else {
    Write-Host "  ℹ Service not installed (this is normal for first setup)" -ForegroundColor Gray
}

Write-Host "`n=== TEST COMPLETE ===" -ForegroundColor Cyan
Write-Host "`nQuick commands:" -ForegroundColor Yellow
Write-Host "1. Start dashboard: cd C:\GuardianFW\scripts; .\dashboard.ps1" -ForegroundColor Gray
Write-Host "2. Run monitor: cd C:\GuardianFW\scripts; .\enhanced_monitor.ps1" -ForegroundColor Gray
Write-Host "3. Install as service: cd C:\GuardianFW\scripts; .\startup.ps1 -InstallService" -ForegroundColor Gray
