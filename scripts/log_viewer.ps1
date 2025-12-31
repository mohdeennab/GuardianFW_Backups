# GuardianFW Log Viewer
# Use this to view and analyze logs

function Show-Logs {
    param(
        [string]$LogDate = (Get-Date -Format "yyyy-MM-dd"),
        [switch]$Follow,
        [int]$Tail = 0,
        [string]$Level,
        [string]$Component,
        [switch]$Statistics
    )
    
    $logPath = "C:\GuardianFW\logs\$LogDate.log"
    
    if (-not (Test-Path $logPath)) {
        Write-Host "Log file not found: $logPath" -ForegroundColor Red
        return
    }
    
    if ($Statistics) {
        Show-LogStatistics -LogPath $logPath
        return
    }
    
    if ($Follow) {
        Write-Host "Following log file: $logPath" -ForegroundColor Cyan
        Write-Host "Press Ctrl+C to stop..." -ForegroundColor Yellow
        Write-Host ""
        
        Get-Content $logPath -Wait | ForEach-Object {
            try {
                if (-not [string]::IsNullOrWhiteSpace($_)) {
                    $logEntry = $_ | ConvertFrom-Json -ErrorAction Stop
                    if (ShouldDisplay -LogEntry $logEntry -Level $Level -Component $Component) {
                        Display-LogEntry $logEntry
                    }
                }
            } catch {
                # Skip invalid JSON lines
            }
        }
    } else {
        $lines = if ($Tail -gt 0) { 
            Get-Content $logPath -Tail $Tail 
        } else { 
            Get-Content $logPath 
        }
        
        $filteredCount = 0
        foreach ($line in $lines) {
            try {
                if (-not [string]::IsNullOrWhiteSpace($line)) {
                    $logEntry = $line | ConvertFrom-Json -ErrorAction Stop
                    if (ShouldDisplay -LogEntry $logEntry -Level $Level -Component $Component) {
                        Display-LogEntry $logEntry
                        $filteredCount++
                    }
                }
            } catch {
                # Skip invalid JSON lines
            }
        }
        
        if ($filteredCount -eq 0) {
            Write-Host "No matching log entries found." -ForegroundColor Yellow
        }
    }
}

function ShouldDisplay {
    param($LogEntry, $Level, $Component)
    
    $levelMatch = [string]::IsNullOrEmpty($Level) -or ($LogEntry.Level -eq $Level)
    $componentMatch = [string]::IsNullOrEmpty($Component) -or ($LogEntry.Component -eq $Component)
    
    return $levelMatch -and $componentMatch
}

function Display-LogEntry {
    param($LogEntry)
    
    $timestamp = $LogEntry.Timestamp
    if ($timestamp.Length -gt 19) {
        $timestamp = $timestamp.Substring(11, 8)  # Extract HH:mm:ss
    }
    
    $color = switch ($LogEntry.Level) {
        'Error' { 'Red' }
        'Warning' { 'Yellow' }
        'Info' { 'Green' }
        'Debug' { 'Gray' }
        'Critical' { 'DarkRed' }
        default { 'White' }
    }
    
    Write-Host "$timestamp [$($LogEntry.Level.PadRight(7))] $($LogEntry.Component.PadRight(10)): $($LogEntry.Message)" -ForegroundColor $color
}

function Show-LogStatistics {
    param($LogPath)
    
    $stats = @{
        TotalEntries = 0
        ByLevel = @{}
        ByComponent = @{}
        Errors = 0
        Warnings = 0
    }
    
    Get-Content $LogPath | ForEach-Object {
        try {
            if (-not [string]::IsNullOrWhiteSpace($_)) {
                $logEntry = $_ | ConvertFrom-Json -ErrorAction Stop
                $stats.TotalEntries++
                
                # Count by level
                if (-not $stats.ByLevel.ContainsKey($logEntry.Level)) {
                    $stats.ByLevel[$logEntry.Level] = 0
                }
                $stats.ByLevel[$logEntry.Level]++
                
                # Count by component
                if (-not $stats.ByComponent.ContainsKey($logEntry.Component)) {
                    $stats.ByComponent[$logEntry.Component] = 0
                }
                $stats.ByComponent[$logEntry.Component]++
                
                # Count errors and warnings
                if ($logEntry.Level -eq 'Error') { $stats.Errors++ }
                if ($logEntry.Level -eq 'Warning') { $stats.Warnings++ }
            }
        } catch {
            # Skip invalid entries
        }
    }
    
    Write-Host "=== Log Statistics ===" -ForegroundColor Cyan
    Write-Host "Log file: $LogPath" -ForegroundColor Yellow
    Write-Host "Total entries: $($stats.TotalEntries)" -ForegroundColor White
    Write-Host "Errors: $($stats.Errors)" -ForegroundColor Red
    Write-Host "Warnings: $($stats.Warnings)" -ForegroundColor Yellow
    
    Write-Host "`nEntries by Level:" -ForegroundColor Cyan
    $stats.ByLevel.GetEnumerator() | Sort-Object Name | ForEach-Object {
        $color = switch ($_.Name) {
            'Error' { 'Red' }
            'Warning' { 'Yellow' }
            'Info' { 'Green' }
            default { 'White' }
        }
        $percentage = [math]::Round(($_.Value / $stats.TotalEntries) * 100, 1)
        Write-Host "  $($_.Name.PadRight(7)): $($_.Value) ($percentage%)" -ForegroundColor $color
    }
    
    Write-Host "`nEntries by Component:" -ForegroundColor Cyan
    $stats.ByComponent.GetEnumerator() | Sort-Object Name | ForEach-Object {
        Write-Host "  $($_.Name.PadRight(15)): $($_.Value)" -ForegroundColor Gray
    }
}

# Export functions
Export-ModuleMember -Function Show-Logs, Show-LogStatistics
