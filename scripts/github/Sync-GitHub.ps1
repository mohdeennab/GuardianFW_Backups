<#
.SYNOPSIS
    Automated GitHub synchronization for GuardianFW
#>

# Configuration
$Config = @{
    ProjectPath = "C:\GuardianFW"
    Repository = "mohdeennab/GuardianFW_Backups"
    SyncInterval = 300  # seconds
    LogPath = "C:\GuardianFW\logs\github-sync.log"
    MaxBackups = 10
}

# Initialize
function Initialize-Sync {
    Write-Host "Initializing GitHub Sync Service..." -ForegroundColor Cyan
    
    $taskName = "GuardianFW_GitHub_Sync"
    $taskAction = New-ScheduledTaskAction -Execute "PowerShell.exe" `
        -Argument "-NoProfile -ExecutionPolicy Bypass -File `"$PSScriptRoot\Sync-GitHub.ps1`" -AutoSync"
    
    $taskTrigger = New-ScheduledTaskTrigger -Daily -At "2:00AM"
    $taskPrincipal = New-ScheduledTaskPrincipal -UserId "SYSTEM" -LogonType ServiceAccount -RunLevel Highest
    
    Register-ScheduledTask -TaskName $taskName `
        -Action $taskAction `
        -Trigger $taskTrigger `
        -Principal $taskPrincipal `
        -Description "Automated GitHub sync for GuardianFW" `
        -Force | Out-Null
    
    Write-Host " Scheduled task created: $taskName" -ForegroundColor Green
}

# Monitor changes
function Get-ProjectChanges {
    param([string]$Path)
    
    $lastSyncFile = Join-Path (Split-Path $Config.LogPath -Parent) "last_sync.json"
    if (Test-Path $lastSyncFile) {
        $lastSyncData = Get-Content $lastSyncFile | ConvertFrom-Json
        $lastSyncTime = $lastSyncData.LastSync
    } else {
        $lastSyncTime = [DateTime]::MinValue
    }
    
    $changes = Get-ChildItem -Path $Path -Recurse -File -ErrorAction SilentlyContinue |
        Where-Object { $_.LastWriteTime -gt $lastSyncTime } |
        Select-Object FullName, LastWriteTime, Length
    
    return @{
        Count = $changes.Count
        Files = $changes
        LastSync = $lastSyncTime
    }
}

# Auto-sync function
function Start-AutoSync {
    Write-Host "[$(Get-Date -Format 'HH:mm:ss')] Checking for changes..." -ForegroundColor Cyan
    
    $changes = Get-ProjectChanges -Path $Config.ProjectPath
    
    if ($changes.Count -gt 0) {
        Write-Host " Found $($changes.Count) changed files. Syncing to GitHub..." -ForegroundColor Yellow
        
        # Run backup
        & "$PSScriptRoot\Backup-ToGitHub.ps1" -Mode Incremental -Repository $Config.Repository
        
        # Update last sync time
        @{ LastSync = Get-Date -Format "yyyy-MM-dd HH:mm:ss" } |
            ConvertTo-Json |
            Out-File -FilePath (Join-Path (Split-Path $Config.LogPath -Parent) "last_sync.json") -Encoding UTF8
    } else {
        Write-Host " No changes detected" -ForegroundColor Green
    }
}

# Main execution
if ($args[0] -eq "-AutoSync") {
    # Running in auto mode
    while ($true) {
        Start-AutoSync
        Start-Sleep -Seconds $Config.SyncInterval
    }
} elseif ($args[0] -eq "-Install") {
    Initialize-Sync
} else {
    # Interactive mode
    Write-Host "GuardianFW GitHub Sync Utility" -ForegroundColor Cyan
    Write-Host "1. Install auto-sync service"
    Write-Host "2. Run manual sync"
    Write-Host "3. Check sync status"
    Write-Host "4. View sync log"
    
    $choice = Read-Host "Select option (1-4)"
    
    switch ($choice) {
        "1" { Initialize-Sync }
        "2" { 
            & "$PSScriptRoot\Backup-ToGitHub.ps1" -Mode Incremental -Repository $Config.Repository
        }
        "3" {
            $changes = Get-ProjectChanges -Path $Config.ProjectPath
            Write-Host "`nSync Status:" -ForegroundColor Cyan
            Write-Host "Last Sync: $($changes.LastSync)"
            Write-Host "Pending Changes: $($changes.Count) files"
        }
        "4" {
            if (Test-Path $Config.LogPath) {
                Get-Content $Config.LogPath -Tail 50
            } else {
                Write-Host "No log file found" -ForegroundColor Yellow
            }
        }
    }
}
