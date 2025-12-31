# GuardianFW Simple Dashboard
# Reliable version without complex calculations

function Show-SimpleDashboard {
    Clear-Host
    
    while ($true) {
        Clear-Host
        
        Write-Host "================================================" -ForegroundColor Cyan
        Write-Host "          GUARDIANFW SIMPLE DASHBOARD" -ForegroundColor Cyan
        Write-Host "================================================" -ForegroundColor Cyan
        Write-Host ""
        
        # Get basic system info (simple version)
        $computerName = $env:COMPUTERNAME
        $os = (Get-CimInstance Win32_OperatingSystem).Caption
        $uptime = [math]::Round((Get-Date) - (Get-CimInstance Win32_OperatingSystem).LastBootUpTime).TotalHours, 1)
        
        # GuardianFW status
        $configPath = "C:\GuardianFW\config\settings.json"
        $firewallName = "GuardianFW"
        $version = "3.2"
        if (Test-Path $configPath) {
            try {
                $config = Get-Content $configPath | ConvertFrom-Json
                $firewallName = $config.FirewallName
                $version = $config.Version
            } catch { }
        }
        
        # Count files
        $logCount = (Get-ChildItem "C:\GuardianFW\logs\*.log" -ErrorAction SilentlyContinue).Count
        $queueCount = (Get-ChildItem "C:\GuardianFW\queue\*.json" -ErrorAction SilentlyContinue).Count
        
        # Display status
        Write-Host "[SYSTEM]" -ForegroundColor Yellow
        Write-Host "  Computer: $computerName"
        Write-Host "  OS: $os"
        Write-Host "  Uptime: $uptime hours"
        Write-Host ""
        
        Write-Host "[GUARDIANFW]" -ForegroundColor Yellow
        Write-Host "  Name: $firewallName v$version"
        Write-Host "  Log Files: $logCount"
        Write-Host "  Queue: $queueCount pending"
        Write-Host ""
        
        # Show recent logs
        Write-Host "[RECENT LOGS]" -ForegroundColor Yellow
        $todayLog = "C:\GuardianFW\logs\$(Get-Date -Format 'yyyy-MM-dd').log"
        if (Test-Path $todayLog) {
            $recentLogs = Get-Content $todayLog -Tail 5 | ForEach-Object {
                try {
                    if (-not [string]::IsNullOrWhiteSpace($_)) {
                        $log = $_ | ConvertFrom-Json -ErrorAction Stop
                        $time = if ($log.Timestamp.Length -gt 10) { $log.Timestamp.Substring(11, 8) } else { $log.Timestamp }
                        $level = $log.Level.Substring(0, 1)  # Just first letter
                        $color = switch ($log.Level) {
                            'Error' { 'Red' }
                            'Warning' { 'Yellow' }
                            'Info' { 'Green' }
                            default { 'White' }
                        }
                        $msg = if ($log.Message.Length -gt 30) { $log.Message.Substring(0, 30) + "..." } else { $log.Message }
                        Write-Host "  $time [$level] $msg" -ForegroundColor $color
                    }
                } catch { }
            }
        } else {
            Write-Host "  No logs today" -ForegroundColor Gray
        }
        
        Write-Host ""
        Write-Host "[COMMANDS]" -ForegroundColor Yellow
        Write-Host "  1. View logs"
        Write-Host "  2. Clear queue"
        Write-Host "  3. Start monitor"
        Write-Host "  4. Stop monitor"
        Write-Host "  5. Exit"
        Write-Host ""
        Write-Host "Select (1-5): " -NoNewline -ForegroundColor Cyan
        
        $choice = Read-Host
        Write-Host ""
        
        switch ($choice) {
            '1' {
                if (Test-Path $todayLog) {
                    Get-Content $todayLog | ForEach-Object {
                        try {
                            $log = $_ | ConvertFrom-Json -ErrorAction Stop
                            $color = switch ($log.Level) {
                                'Error' { 'Red' }
                                'Warning' { 'Yellow' }
                                'Info' { 'Green' }
                                default { 'White' }
                            }
                            Write-Host "$($log.Timestamp) [$($log.Level)] $($log.Component): $($log.Message)" -ForegroundColor $color
                        } catch { }
                    }
                }
                Write-Host "`nPress Enter to continue..."
                Read-Host
            }
            '2' {
                $queueFiles = Get-ChildItem "C:\GuardianFW\queue\*.json" -ErrorAction SilentlyContinue
                if ($queueFiles) {
                    $queueFiles | Remove-Item -Force
                    Write-Host "Cleared $($queueFiles.Count) queue files" -ForegroundColor Green
                } else {
                    Write-Host "Queue already empty" -ForegroundColor Gray
                }
                Write-Host "`nPress Enter to continue..."
                Read-Host
            }
            '3' {
                Write-Host "Starting monitor (press Ctrl+C in new window to stop)..." -ForegroundColor Yellow
                Start-Process powershell -ArgumentList "-NoExit -Command `"cd 'C:\GuardianFW\scripts'; .\enhanced_monitor.ps1`""
                Write-Host "`nPress Enter to continue..."
                Read-Host
            }
            '4' {
                Write-Host "Stopping monitor processes..." -ForegroundColor Yellow
                Get-Process powershell -ErrorAction SilentlyContinue | Where-Object {
                    $_.CommandLine -match "GuardianFW" -or $_.CommandLine -match "enhanced_monitor"
                } | Stop-Process -Force -ErrorAction SilentlyContinue
                Write-Host "Monitor stopped" -ForegroundColor Green
                Write-Host "`nPress Enter to continue..."
                Read-Host
            }
            '5' {
                return
            }
        }
    }
}

Show-SimpleDashboard
