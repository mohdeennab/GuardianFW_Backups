<#
.SYNOPSIS
    Initializes GitHub repository for GuardianFW backups
#>

param(
    [string]$RepositoryName = "GuardianFW_Backups",
    
    [string]$Description = "Automated backups for GuardianFW Security Platform"
)

Write-Host "Initializing GitHub Repository for GuardianFW..." -ForegroundColor Cyan

# Check if Git is installed
try {
    git --version | Out-Null
} catch {
    Write-Host "Git is not installed. Please install Git first." -ForegroundColor Red
    exit 1
}

# Check if GuardianFW directory exists
$guardianPath = "C:\GuardianFW"
if (-not (Test-Path $guardianPath)) {
    Write-Host "GuardianFW directory not found: $guardianPath" -ForegroundColor Red
    exit 1
}

Write-Host " GuardianFW directory found" -ForegroundColor Green

# Instructions for manual setup
Write-Host @"
 Manual Setup Instructions:

1. Create a new repository on GitHub:
   - Go to: https://github.com/new
   - Name: $RepositoryName
   - Description: $Description
   - Choose Public or Private
   - DO NOT initialize with README

2. After creating, copy the repository URL
   - It should be: https://github.com/yourusername/$RepositoryName.git

3. Run the backup script:
   - Navigate to: C:\GuardianFW\scripts\github
   - Run: .\Backup-ToGitHub.ps1 -Repository "yourusername/$RepositoryName"

4. Enable auto-sync:
   - Run: .\Sync-GitHub.ps1 -Install

Alternatively, if you want to push to an existing repository:
   1. Clone the repository locally
   2. Copy GuardianFW files to the repository
   3. Commit and push

Note: For automated authentication, set a GitHub Personal Access Token:
   [System.Environment]::SetEnvironmentVariable("GITHUB_TOKEN", "your_token", "Machine")
"@ -ForegroundColor Yellow
