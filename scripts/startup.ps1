# GuardianFW Startup Script
# Place this in Windows Task Scheduler to run at startup

param(
    [switch]$InstallService,
    [switch]$UninstallService
)

$ErrorActionPreference = "Stop"

# Import logging
. "C:\GuardianFW\scripts\log_functions.ps1"

function Install-GuardianService {
    Write-Host "[INFO] Installing GuardianFW as Windows Service..." -ForegroundColor Yellow
    
    $serviceName = "GuardianFW"
    $serviceDisplayName = "Guardian Firewall Service"
    $serviceDescription = "AI-Powered Next-Generation Firewall with Splunk Integration"
    
    # Check if service already exists
    $existingService = Get-Service -Name $serviceName -ErrorAction SilentlyContinue
    
    if ($existingService) {
        Write-Host "[INFO] Service already exists. Stopping and removing..." -ForegroundColor Yellow
        Stop-Service -Name $serviceName -Force -ErrorAction SilentlyContinue
        sc.exe delete $serviceName
        Start-Sleep -Seconds 2
    }
    
    # Create new service using PowerShell Core if available, otherwise PowerShell 5
    $powershellPath = "C:\Windows\System32\WindowsPowerShell\v1.0\powershell.exe"
    if (Test-Path "C:\Program Files\PowerShell\7\pwsh.exe") {
        $powershellPath = "C:\Program Files\PowerShell\7\pwsh.exe"
    }
    
    $serviceCommand = "`"$powershellPath`" -ExecutionPolicy Bypass -File `"C:\GuardianFW\scripts\monitor.ps1`""
    
    # Create service
    $serviceArgs = @(
        "create",
        $serviceName,
        "binPath=`"$serviceCommand`"",
        "DisplayName=`"$serviceDisplayName`"",
        "start=auto",
        "obj=LocalSystem"
    )
    
    $result = sc.exe $serviceArgs
    
    if ($LASTEXITCODE -eq 0) {
        # Set service description
        $descriptionArgs = @(
            "description",
            $serviceName,
            "`"$serviceDescription`""
        )
        sc.exe $descriptionArgs | Out-Null
        
        Write-Host "[SUCCESS] Service installed successfully" -ForegroundColor Green
        Write-Host "[INFO] Starting service..." -ForegroundColor Yellow
        Start-Service -Name $serviceName
        Write-Host "[SUCCESS] Service started" -ForegroundColor Green
    } else {
        Write-Host "[ERROR] Failed to create service: $result" -ForegroundColor Red
    }
}

function Uninstall-GuardianService {
    Write-Host "[INFO] Uninstalling GuardianFW service..." -ForegroundColor Yellow
    
    $serviceName = "GuardianFW"
    $existingService = Get-Service -Name $serviceName -ErrorAction SilentlyContinue
    
    if ($existingService) {
        # Stop service
        if ($existingService.Status -eq "Running") {
            Stop-Service -Name $serviceName -Force
            Write-Host "[INFO] Service stopped" -ForegroundColor Yellow
        }
        
        # Delete service
        sc.exe delete $serviceName
        Write-Host "[SUCCESS] Service uninstalled" -ForegroundColor Green
    } else {
        Write-Host "[INFO] Service not found" -ForegroundColor Gray
    }
}

# Main execution
try {
    Write-GuardianLog -Message "GuardianFW startup script executed" -Level Info -Component "Startup"
    
    if ($UninstallService) {
        Uninstall-GuardianService
    } elseif ($InstallService) {
        Install-GuardianService
    } else {
        # Just run the monitor directly
        Write-Host "[INFO] Starting GuardianFW Monitor..." -ForegroundColor Yellow
        & "C:\GuardianFW\scripts\monitor.ps1"
    }
    
} catch {
    $errorMsg = $_.Exception.Message
    Write-Host "[FATAL] Startup script error: $errorMsg" -ForegroundColor Red
    Write-GuardianLog -Message "Startup script failed: $errorMsg" -Level Error -Component "Startup"
    exit 1
}
