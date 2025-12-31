# GuardianFW Main Monitor
# Version: 1.0

param(
    [string]$ConfigPath = "C:\GuardianFW\config\settings.json"
)

# Import logging module
. "C:\GuardianFW\scripts\log_functions.ps1"

# Initialize logging
$logConfig = Initialize-Logging -ConfigPath $ConfigPath

Write-GuardianLog -Message "GuardianFW Monitor starting..." -Level Info -Component "Monitor"

try {
    # Load configuration
    if (Test-Path $ConfigPath) {
        $config = Get-Content $ConfigPath | ConvertFrom-Json
        Write-GuardianLog -Message "Configuration loaded" -Level Info -Component "Monitor"
    } else {
        Write-GuardianLog -Message "Configuration file not found: $ConfigPath" -Level Error -Component "Monitor"
        exit 1
    }
    
    # Main monitoring loop
    Write-GuardianLog -Message "Starting main monitoring loop" -Level Info -Component "Monitor"
    
    $running = $true
    $cycleCount = 0
    
    while ($running) {
        $cycleCount++
        
        # 1. Check system health
        Write-GuardianLog -Message "Cycle $cycleCount - Checking system health..." -Level Debug -Component "Monitor"
        
        # 2. Check for queued logs to send
        $queuePath = "C:\GuardianFW\queue\"
        if (Test-Path $queuePath) {
            $queuedFiles = Get-ChildItem $queuePath -Filter "*.json" -ErrorAction SilentlyContinue
            if ($queuedFiles.Count -gt 0) {
                Write-GuardianLog -Message "Found $($queuedFiles.Count) queued files to process" -Level Info -Component "Monitor"
            }
        }
        
        # 3. Check log rotation
        if ($config.Logging.EnableLogRotation) {
            Check-LogRotation -Config $config
        }
        
        # 4. Sleep for interval
        $interval = 10  # seconds
        Write-GuardianLog -Message "Sleeping for $interval seconds..." -Level Debug -Component "Monitor"
        Start-Sleep -Seconds $interval
        
        # Break after 10 cycles for testing
        if ($cycleCount -ge 10) {
            Write-GuardianLog -Message "Test cycles completed. Exiting..." -Level Info -Component "Monitor"
            $running = $false
        }
    }
    
} catch {
    Write-GuardianLog -Message "Monitor error: $_" -Level Error -Component "Monitor"
    Write-Host "[FATAL] Monitor crashed: $_" -ForegroundColor Red
    exit 1
}

Write-GuardianLog -Message "GuardianFW Monitor stopped" -Level Info -Component "Monitor"

# Helper Functions
function Check-LogRotation {
    param($Config)
    
    $logPath = "C:\GuardianFW\logs\"
    $maxSizeMB = $Config.Logging.MaxLogSizeMB
    $retentionDays = $Config.Logging.RetentionDays
    
    try {
        # Check current log size
        $logFiles = Get-ChildItem $logPath -Filter "*.log" -ErrorAction SilentlyContinue
        if ($logFiles) {
            $totalSizeMB = ($logFiles | Measure-Object -Property Length -Sum).Sum / 1MB
            
            if ($totalSizeMB -gt $maxSizeMB) {
                Write-GuardianLog -Message "Log size ($totalSizeMB MB) exceeds limit ($maxSizeMB MB)" -Level Warning -Component "LogRotation"
                # TODO: Implement rotation logic
            }
        }
        
        # Check old logs for cleanup
        $cutoffDate = (Get-Date).AddDays(-$retentionDays)
        $oldLogs = Get-ChildItem $logPath -Filter "*.log" -ErrorAction SilentlyContinue | 
                   Where-Object { $_.LastWriteTime -lt $cutoffDate }
        
        if ($oldLogs.Count -gt 0) {
            Write-GuardianLog -Message "Found $($oldLogs.Count) logs older than $retentionDays days" -Level Info -Component "LogRotation"
            # TODO: Implement cleanup logic
        }
        
    } catch {
        Write-GuardianLog -Message "Log rotation check failed: $_" -Level Error -Component "LogRotation"
    }
}
