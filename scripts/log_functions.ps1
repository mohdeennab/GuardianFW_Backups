# GuardianFW Logging Module
# Version: 1.1 (Fixed)

function Write-GuardianLog {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)]
        [string]$Message,
        
        [ValidateSet('Debug','Info','Warning','Error','Critical')]
        [string]$Level = 'Info',
        
        [string]$Component = "General",
        
        [string]$LogPath = "C:\GuardianFW\logs\"
    )
    
    try {
        # Sanitize message (basic)
        $safeMessage = $Message -replace '[^\x20-\x7E]', ''
        if ($safeMessage.Length -gt 1000) {
            $safeMessage = $safeMessage.Substring(0, 1000) + "...[TRUNCATED]"
        }
        
        # Create log entry
        $logEntry = @{
            Timestamp = Get-Date -Format "yyyy-MM-ddTHH:mm:ss.fffZ"
            Level = $Level
            Component = $Component
            Message = $safeMessage
            Hostname = $env:COMPUTERNAME
            ProcessId = $PID
            ThreadId = [System.Threading.Thread]::CurrentThread.ManagedThreadId
        }
        
        # Convert to JSON
        $jsonEntry = $logEntry | ConvertTo-Json -Compress
        
        # Ensure log directory exists
        if (-not (Test-Path $LogPath)) {
            New-Item -ItemType Directory -Path $LogPath -Force | Out-Null
        }
        
        # Write to daily log file
        $logFile = Join-Path $LogPath "$(Get-Date -Format 'yyyy-MM-dd').log"
        Add-Content -Path $logFile -Value $jsonEntry -Encoding UTF8
        
        # Also output to console based on level - FIXED SYNTAX
        $outputMessage = "[$Level] ${Component}: $safeMessage"
        switch ($Level) {
            'Error' { Write-Host $outputMessage -ForegroundColor Red }
            'Warning' { Write-Host $outputMessage -ForegroundColor Yellow }
            'Info' { Write-Host $outputMessage -ForegroundColor Green }
            'Debug' { Write-Host $outputMessage -ForegroundColor Gray }
            default { Write-Host $outputMessage }
        }
        
        return $true
    } catch {
        Write-Host "[CRITICAL] Failed to write log: $_" -ForegroundColor Red
        return $false
    }
}

function Initialize-Logging {
    param([string]$ConfigPath = "C:\GuardianFW\config\settings.json")
    
    try {
        if (Test-Path $ConfigPath) {
            $config = Get-Content $ConfigPath | ConvertFrom-Json
            Write-GuardianLog -Message "Logging initialized" -Level Info -Component "Logging"
            return $config.Logging
        } else {
            Write-Host "[WARNING] Configuration file not found: $ConfigPath" -ForegroundColor Yellow
            return @{ LogLevel = "Info" }
        }
    } catch {
        Write-Host "[ERROR] Failed to initialize logging: $_" -ForegroundColor Red
        return @{ LogLevel = "Info" }
    }
}



