<#
.SYNOPSIS
    GuardianFW GitHub Backup Manager
.DESCRIPTION
    Comprehensive backup and synchronization tool for GuardianFW project to GitHub
    Creates archives, commits changes, and manages releases automatically
#>

[CmdletBinding()]
param(
    [Parameter(Position=0)]
    [ValidateSet("Full", "Incremental", "DatabaseOnly", "ConfigOnly")]
    [string]$Mode = "Full",
    
    [string]$Repository = "mohdeennab/GuardianFW_Backups",
    
    [switch]$CreateRelease,
    
    [string]$Version = "1.0.0",
    
    [string]$GitHubToken,
    
    [string]$BackupPath = "C:\GuardianFW\backups\github",
    
    [switch]$Force,
    
    [switch]$Compress
)

# Configuration
$Config = @{
    ProjectName = "GuardianFW"
    ProjectRoot = "C:\GuardianFW"
    Repository = $Repository
    GitHubToken = $GitHubToken
    TempPath = "C:\Temp\GuardianFW_GitHub"
    LogPath = "C:\GuardianFW\logs\github-backup.log"
}

# Initialize logging
function Initialize-Logging {
    param([string]$LogPath)
    
    $logDir = Split-Path $LogPath -Parent
    if (-not (Test-Path $logDir)) {
        New-Item -Path $logDir -ItemType Directory -Force | Out-Null
    }
    
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $logHeader = @"

               GUARDIANFW GITHUB BACKUP LOG               

 Start Time: $timestamp
 Mode: $Mode
 Repository: $Repository
 Version: $Version

"@
    
    $logHeader | Out-File -FilePath $LogPath -Encoding UTF8
}

function Write-Log {
    param(
        [string]$Message,
        [ValidateSet("INFO", "SUCCESS", "WARNING", "ERROR", "DEBUG")]
        [string]$Level = "INFO"
    )
    
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $logEntry = "[$timestamp] [$Level] $Message"
    
    $colorMap = @{
        "INFO" = "White"
        "SUCCESS" = "Green"
        "WARNING" = "Yellow"
        "ERROR" = "Red"
        "DEBUG" = "Gray"
    }
    
    Write-Host $logEntry -ForegroundColor $colorMap[$Level]
    $logEntry | Out-File -FilePath $Config.LogPath -Encoding UTF8 -Append
}

# Check prerequisites
function Test-Prerequisites {
    Write-Log "Checking prerequisites..." "INFO"
    
    # Check Git
    try {
        $gitVersion = git --version
        Write-Log "Git version: $gitVersion" "SUCCESS"
    } catch {
        Write-Log "Git is not installed. Please install from: https://git-scm.com/" "ERROR"
        return $false
    }
    
    # Check project directory
    if (-not (Test-Path $Config.ProjectRoot)) {
        Write-Log "GuardianFW directory not found: $($Config.ProjectRoot)" "ERROR"
        return $false
    }
    Write-Log "Project directory found: $($Config.ProjectRoot)" "SUCCESS"
    
    return $true
}

# Create backup archive
function New-BackupArchive {
    param(
        [string]$SourcePath,
        [string]$DestinationPath,
        [string]$BackupName
    )
    
    Write-Log "Creating backup archive: $BackupName" "INFO"
    
    $timestamp = Get-Date -Format "yyyyMMdd_HHmmss"
    $archiveName = "$BackupName-$timestamp"
    $archivePath = Join-Path $DestinationPath $archiveName
    
    # Create temporary directory
    $tempBackupPath = Join-Path $env:TEMP "GuardianFW_Backup_$timestamp"
    New-Item -Path $tempBackupPath -ItemType Directory -Force | Out-Null
    
    try {
        # Simple copy of project files (excluding logs and temp files)
        Get-ChildItem -Path $SourcePath -Exclude @("logs", "temp", "cache", "backups", "*.log", "*.tmp") | 
            Copy-Item -Destination $tempBackupPath -Recurse -Force
        
        # Create manifest
        $manifest = @{
            BackupName = $BackupName
            Project = "GuardianFW"
            Version = $Version
            Mode = $Mode
            Timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
            SystemInfo = @{
                Hostname = $env:COMPUTERNAME
                OS = (Get-WmiObject Win32_OperatingSystem).Caption
                User = "$env:USERDOMAIN\$env:USERNAME"
            }
        }
        
        $manifest | ConvertTo-Json -Depth 5 | Out-File -FilePath (Join-Path $tempBackupPath "BACKUP_MANIFEST.json") -Encoding UTF8
        
        # Compress if requested
        if ($Compress) {
            $archivePath += ".zip"
            Compress-Archive -Path "$tempBackupPath\*" -DestinationPath $archivePath -CompressionLevel Optimal
            Write-Log "Compressed archive created: $archivePath" "SUCCESS"
        } else {
            Copy-Item -Path $tempBackupPath -Destination $archivePath -Recurse
            Write-Log "Uncompressed backup created: $archivePath" "SUCCESS"
        }
        
        # Calculate size
        $size = (Get-ChildItem $archivePath -Recurse | Measure-Object -Property Length -Sum).Sum
        $sizeMB = [math]::Round($size / 1MB, 2)
        
        Write-Log "Backup completed. Size: ${sizeMB}MB" "SUCCESS"
        
        return @{
            Path = $archivePath
            SizeMB = $sizeMB
            Timestamp = $timestamp
        }
        
    } finally {
        # Cleanup
        if (Test-Path $tempBackupPath) {
            Remove-Item -Path $tempBackupPath -Recurse -Force
        }
    }
}

# Initialize Git repository
function Initialize-GitRepository {
    param(
        [string]$LocalPath,
        [string]$RemoteUrl
    )
    
    Write-Log "Initializing Git repository..." "INFO"
    
    Set-Location $LocalPath
    
    if (Test-Path ".git") {
        Write-Log "Git repository already exists" "INFO"
        $currentRemote = git remote get-url origin 2>$null
        if ($currentRemote -ne $RemoteUrl) {
            Write-Log "Updating remote URL from $currentRemote to $RemoteUrl" "WARNING"
            git remote set-url origin $RemoteUrl
        }
    } else {
        Write-Log "Initializing new Git repository" "INFO"
        git init
        
        # Configure git
        git config user.email "guardianfw@backup.local"
        git config user.name "GuardianFW Backup"
        
        # Add remote
        git remote add origin $RemoteUrl
    }
    
    Write-Log "Git repository initialized successfully" "SUCCESS"
}

# Push to GitHub
function Push-ToGitHub {
    param(
        [string]$LocalPath,
        [string]$CommitMessage
    )
    
    Write-Log "Pushing to GitHub repository..." "INFO"
    
    Set-Location $LocalPath
    
    try {
        git add --all
        git commit -m $CommitMessage
        
        if ($Force) {
            git push -u origin main --force
        } else {
            git push -u origin main
        }
        
        Write-Log "Successfully pushed to GitHub" "SUCCESS"
        return $true
        
    } catch {
        Write-Log "Git push failed: $_" "ERROR"
        
        # Try with token if available
        if ($Config.GitHubToken) {
            Write-Log "Attempting push with authentication..." "INFO"
            $remoteUrl = "https://$($Config.GitHubToken)@github.com/$($Config.Repository).git"
            git remote set-url origin $remoteUrl
            
            try {
                git push -u origin main
                Write-Log "Push with authentication succeeded" "SUCCESS"
                return $true
            } catch {
                Write-Log "Authenticated push also failed: $_" "ERROR"
            }
        }
        
        return $false
    }
}

# Main execution
function Start-Backup {
    Write-Host @"

                GUARDIANFW GITHUB BACKUP                   

 Repository: $($Config.Repository)
 Mode: $Mode
 Version: $Version
 Timestamp: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')

"@ -ForegroundColor Cyan
    
    # Initialize logging
    Initialize-Logging -LogPath $Config.LogPath
    
    if (-not (Test-Prerequisites)) {
        Write-Log "Prerequisites check failed. Exiting." "ERROR"
        exit 1
    }
    
    # Ensure backup directory exists
    if (-not (Test-Path $BackupPath)) {
        New-Item -Path $BackupPath -ItemType Directory -Force | Out-Null
    }
    
    # Create backup archive
    $backupResult = New-BackupArchive `
        -SourcePath $Config.ProjectRoot `
        -DestinationPath $BackupPath `
        -BackupName "GuardianFW-$Mode"
    
    if (-not $backupResult) {
        Write-Log "Backup creation failed" "ERROR"
        exit 1
    }
    
    # Clone or initialize repository
    $repoName = $Config.Repository.Split('/')[-1]
    $localRepoPath = Join-Path $Config.TempPath $repoName
    
    if (Test-Path $localRepoPath) {
        Remove-Item -Path $localRepoPath -Recurse -Force
    }
    
    New-Item -Path $localRepoPath -ItemType Directory -Force | Out-Null
    
    # Initialize Git
    $remoteUrl = "https://github.com/$($Config.Repository).git"
    Initialize-GitRepository -LocalPath $localRepoPath -RemoteUrl $remoteUrl
    
    # Copy backup to repo
    Copy-Item -Path $backupResult.Path -Destination $localRepoPath -Recurse
    
    # Create README
    $readmeContent = @"
# GuardianFW Backup Repository

## Latest Backup Information
- **Version:** $Version
- **Backup Mode:** $Mode
- **Timestamp:** $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')
- **Size:** $($backupResult.SizeMB) MB

## Repository Structure
\`\`\`
$repoName/
 backups/          # Backup archives
 manifests/        # Backup metadata
 scripts/          # Backup utilities
 README.md        # This file
\`\`\`

## Links
- [GuardianFW Documentation](https://github.com/mohdeennab/GuardianFW)
- [Main Project Repository](https://github.com/mohdeennab/GuardianFW)
"@
    
    $readmeContent | Out-File -FilePath (Join-Path $localRepoPath "README.md") -Encoding UTF8
    
    # Push to GitHub
    $commitMessage = "GuardianFW $Mode Backup v$Version - $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')"
    $pushResult = Push-ToGitHub -LocalPath $localRepoPath -CommitMessage $commitMessage
    
    # Generate report
    $report = @{
        Status = "COMPLETED"
        Timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
        Backup = $backupResult
        Repository = $Config.Repository
        PushSuccessful = $pushResult
        LogFile = $Config.LogPath
    }
    
    $report | ConvertTo-Json -Depth 5 | Out-File -FilePath (Join-Path $BackupPath "backup_report.json") -Encoding UTF8
    
    Write-Log "Backup process completed successfully" "SUCCESS"
    Write-Host "`n Backup completed! Log saved to: $($Config.LogPath)" -ForegroundColor Green
}

# Execute
try {
    Start-Backup
} catch {
    Write-Host " Backup failed: $_" -ForegroundColor Red
    exit 1
}
