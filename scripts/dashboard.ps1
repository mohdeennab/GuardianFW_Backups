# GuardianFW Dashboard
# Run this to see real-time status and logs

function Show-Dashboard {
    Clear-Host
    
    # Load configuration
    $configPath = "C:\GuardianFW\config\settings.json"
    if (Test-Path $configPath) {
        $config = Get-Content $configPath | ConvertFrom-Json
    }
    
    # System info
    $computerInfo = Get-CimInstance Win32_ComputerSystem
    $osInfo = Get-CimInstance Win32_OperatingSystem
    $cpu = Get-Counter '\Processor(_Total)\% Processor Time' -ErrorAction SilentlyContinue
    $memory = Get-Counter '\Memory\% Committed Bytes In Use' -ErrorAction SilentlyContinue
    
    # GuardianFW info
    $logFiles = Get-ChildItem "C:\GuardianFW\logs\*.log" -ErrorAction SilentlyContinue
    $queueFiles = Get-ChildItem "C:\GuardianFW\queue\*.json" -ErrorAction SilentlyContinue
    $logCount = if ($logFiles) { ($logFiles | ForEach-Object { (Get-Content $_ | Measure-Object -Line).Lines } | Measure-Object -Sum).Sum } else { 0 }
    
    while ($true) {
        Clear-Host
        
        Write-Host "================================================================" -ForegroundColor Cyan
        Write-Host "                   GUARDIANFW DASHBOARD" -ForegroundColor Cyan
        Write-Host "================================================================" -ForegroundColor Cyan
        Write-Host ""
        
        # System Status
        Write-Host "[SYSTEM STATUS]" -ForegroundColor Yellow
        Write-Host "  Computer: $($computerInfo.Name)"
        Write-Host "  OS: $($osInfo.Caption) ($($osInfo.Version))"
        Write-Host "  Uptime: $([math]::Round($osInfo.SystemUpTime.TotalHours, 2)) hours"
        Write-Host "  CPU Usage: $([math]::Round($cpu.CounterSamples.CookedValue, 1))%"
        Write-Host "  Memory Usage: $([math]::Round($memory.CounterSamples.CookedValue, 1))%"
        Write-Host ""
        
        # GuardianFW Status
        Write-Host "[GUARDIANFW STATUS]" -ForegroundColor Yellow
        Write-Host "  Firewall Name: $($config.FirewallName)"
        Write-Host "  Version: $($config.Version)"
        Write-Host "  Splunk: $(if ($config.Splunk.Enabled) { 'ENABLED' } else { 'DISABLED' })"
        Write-Host "  Log Files: $($logFiles.Count) files, $logCount entries"
        Write-Host "  Queue: $($queueFiles.Count) pending files"
        Write-Host "  Log Level: $($config.Logging.LogLevel)"
        Write-Host ""
        
        # Recent Logs
        Write-Host "[RECENT LOGS]" -ForegroundColor Yellow
        $todayLog = "C:\GuardianFW\logs\$(Get-Date -Format 'yyyy-MM-dd').log"
        if (Test-Path $todayLog) {
            $recentLogs = Get-Content $todayLog -Tail 10 | ForEach-Object {
                try {
                    $logEntry = $_ | ConvertFrom-Json -ErrorAction SilentlyContinue
                    if ($logEntry) {
                        $time = $logEntry.Timestamp.Substring(11, 8)
                        $level = $logEntry.Level.PadRight(7)
                        $comp = $logEntry.Component.PadRight(10)
                        $msg = $logEntry.Message.Substring(0, [Math]::Min($logEntry.Message.Length, 40))
                        
                        # Color code by level
                        $color = switch ($logEntry.Level) {
                            'Error' { 'Red' }
                            'Warning' { 'Yellow' }
                            'Info' { 'Green' }
                            'Debug' { 'Gray' }
                            default { 'White' }
                        }
                        
                        # FIXED: Use string concatenation instead of variable with colon
                        $outputLine = "  $time [$level] $($comp): $msg"
                        Write-Host $outputLine -ForegroundColor $color
                    }
                } catch { }
            }
        } else {
            Write-Host "  No logs for today" -ForegroundColor Gray
        }
        
        Write-Host ""
        Write-Host "[MENU]" -ForegroundColor Yellow
        Write-Host "  1. View all today's logs"
        Write-Host "  2. View queue files"
        Write-Host "  3. Check system health"
        Write-Host "  4. Run monitor (test mode)"
        Write-Host "  5. Update configuration"
        Write-Host "  6. Exit"
        Write-Host ""
        Write-Host "Press a number (1-6) or 'r' to refresh, 'q' to quit:" -NoNewline
        
        $key = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
        Write-Host ""
        
        switch ($key.Character) {
            '1' { 
                Clear-Host
                Write-Host "Today's Logs:" -ForegroundColor Cyan
                if (Test-Path $todayLog) {
                    Get-Content $todayLog | ForEach-Object {
                        try {
                            $logEntry = $_ | ConvertFrom-Json -ErrorAction SilentlyContinue
                            if ($logEntry) {
                                $color = switch ($logEntry.Level) {
                                    'Error' { 'Red' }
                                    'Warning' { 'Yellow' }
                                    'Info' { 'Green' }
                                    default { 'White' }
                                }
                                Write-Host "$($logEntry.Timestamp) [$($logEntry.Level)] $($logEntry.Component): $($logEntry.Message)" -ForegroundColor $color
                            }
                        } catch { }
                    }
                }
                Write-Host "`nPress any key to continue..."
                $null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
            }
            '2' { 
                Clear-Host
                Write-Host "Queue Files:" -ForegroundColor Cyan
                if ($queueFiles.Count -gt 0) {
                    $queueFiles | ForEach-Object {
                        Write-Host "  $($_.Name) - $($_.LastWriteTime)" -ForegroundColor Yellow
                        try {
                            $content = Get-Content $_.FullName | ConvertFrom-Json
                            Write-Host "    Retry: $($content.RetryCount), Error: $($content.LastError)" -ForegroundColor Gray
                        } catch { }
                    }
                } else {
                    Write-Host "  No files in queue" -ForegroundColor Gray
                }
                Write-Host "`nPress any key to continue..."
                $null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
            }
            '3' { 
                Clear-Host
                Write-Host "System Health Check:" -ForegroundColor Cyan
                $health = Get-SystemHealth
                $health.PSObject.Properties | ForEach-Object {
                    Write-Host "  $($_.Name): $($_.Value)" -ForegroundColor Yellow
                }
                Write-Host "`nPress any key to continue..."
                $null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
            }
            '4' { 
                Write-Host "Starting monitor in test mode (will run for 30 seconds)..." -ForegroundColor Yellow
                powershell -Command "& 'C:\GuardianFW\scripts\enhanced_monitor.ps1' -TestMode -Duration 30"
                Write-Host "Monitor test completed. Press any key to continue..."
                $null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
            }
            '5' { 
                Write-Host "Opening configuration editor..." -ForegroundColor Yellow
                powershell -Command "& 'C:\GuardianFW\scripts\config_editor.ps1'"
            }
            '6' { return }
            'q' { return }
            'r' { continue }
            default { continue }
        }
    }
}

# Helper function - FIXED Threads calculation
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

# Run dashboard
Show-Dashboard
