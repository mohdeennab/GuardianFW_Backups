# GuardianFW Enhanced Monitor with Splunk Integration
# Version: 2.0

param(
    [string]$ConfigPath = "C:\GuardianFW\config\settings.json",
    [switch]$TestMode,
    [int]$Duration = 300  # Run for 5 minutes by default
)

# Import logging module
. "C:\GuardianFW\scripts\log_functions.ps1"

Write-GuardianLog -Message "GuardianFW Enhanced Monitor starting..." -Level Info -Component "Monitor"

# Global variables
$Global:MonitorRunning = $true
$Global:CycleCount = 0
$Global:StartTime = Get-Date
$Global:LastHealthCheck = Get-Date
$Global:LastQueueProcess = Get-Date

# Signal handler for graceful shutdown
Register-EngineEvent -SourceIdentifier PowerShell.Exiting -Action {
    $Global:MonitorRunning = $false
    Write-GuardianLog -Message "Monitor shutdown requested" -Level Info -Component "Monitor"
}

function Get-SystemHealth {
    $health = @{
        Timestamp = Get-Date -Format "o"
        CPU = (Get-Counter '\Processor(_Total)\% Processor Time' -ErrorAction SilentlyContinue).CounterSamples.CookedValue
        Memory = (Get-Counter '\Memory\% Committed Bytes In Use' -ErrorAction SilentlyContinue).CounterSamples.CookedValue
        Disk = (Get-PSDrive C | Select-Object @{Name='FreeGB';Expression={[math]::Round($_.Free/1GB,2)}}, @{Name='UsedGB';Expression={[math]::Round($_.Used/1GB,2)}})
        Processes = (Get-Process).Count
        Threads = (Get-Process | ForEach-Object { # GuardianFW Enhanced Monitor with Splunk Integration
# Version: 2.0

param(
    [string]$ConfigPath = "C:\GuardianFW\config\settings.json",
    [switch]$TestMode,
    [int]$Duration = 300  # Run for 5 minutes by default
)

# Import logging module
. "C:\GuardianFW\scripts\log_functions.ps1"

Write-GuardianLog -Message "GuardianFW Enhanced Monitor starting..." -Level Info -Component "Monitor"

# Global variables
$Global:MonitorRunning = $true
$Global:CycleCount = 0
$Global:StartTime = Get-Date
$Global:LastHealthCheck = Get-Date
$Global:LastQueueProcess = Get-Date

# Signal handler for graceful shutdown
Register-EngineEvent -SourceIdentifier PowerShell.Exiting -Action {
    $Global:MonitorRunning = $false
    Write-GuardianLog -Message "Monitor shutdown requested" -Level Info -Component "Monitor"
}

function Get-SystemHealth {
    $health = @{
        Timestamp = Get-Date -Format "o"
        CPU = (Get-Counter '\Processor(_Total)\% Processor Time' -ErrorAction SilentlyContinue).CounterSamples.CookedValue
        Memory = (Get-Counter '\Memory\% Committed Bytes In Use' -ErrorAction SilentlyContinue).CounterSamples.CookedValue
        Disk = (Get-PSDrive C | Select-Object @{Name='FreeGB';Expression={[math]::Round($_.Free/1GB,2)}}, @{Name='UsedGB';Expression={[math]::Round($_.Used/1GB,2)}})
        Processes = (Get-Process).Count
        Threads = (Get-Process | Measure-Object -Property Threads -Sum).Sum
        Uptime = [math]::Round((New-TimeSpan -Start (Get-CimInstance Win32_OperatingSystem).LastBootUpTime -End (Get-Date)).TotalHours, 2)
    }
    
    return $health
}

function Send-ToSplunk {
    param(
        [Parameter(Mandatory=$true)]
        [object]$EventData,
        
        [Parameter(Mandatory=$true)]
        [string]$EventSource,
        
        [string]$SplunkUrl = "https://localhost:8088"
    )
    
    try {
        # Load token securely
        $tokenPath = "C:\GuardianFW\secure\splunk_token.xml"
        if (-not (Test-Path $tokenPath)) {
            Write-GuardianLog -Message "Splunk token file not found: $tokenPath" -Level Error -Component "Splunk"
            return $false
        }
        
        $secureToken = Import-Clixml -Path $tokenPath
        $token = [System.Runtime.InteropServices.Marshal]::PtrToStringAuto(
            [System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($secureToken)
        )
        
        # Prepare event
        $splunkEvent = @{
            time = Get-Date -Format "yyyy-MM-ddTHH:mm:ss.fffZ"
            host = $env:COMPUTERNAME
            source = $EventSource
            event = $EventData
        }
        
        $jsonBody = $splunkEvent | ConvertTo-Json -Depth 5
        
        # Prepare headers
        $headers = @{
            "Authorization" = "Splunk $token"
            "Content-Type" = "application/json"
        }
        
        # Send to Splunk
        $response = Invoke-RestMethod -Uri $SplunkUrl `
            -Method Post `
            -Headers $headers `
            -Body $jsonBody `
            -ErrorAction Stop
        
        Write-GuardianLog -Message "Event sent to Splunk successfully" -Level Debug -Component "Splunk"
        return $true
        
    } catch {
        Write-GuardianLog -Message "Failed to send to Splunk: $($_.Exception.Message)" -Level Warning -Component "Splunk"
        
        # Queue for retry
        $queuePath = "C:\GuardianFW\queue\"
        if (-not (Test-Path $queuePath)) {
            New-Item -ItemType Directory -Path $queuePath -Force | Out-Null
        }
        
        $queueFile = Join-Path $queuePath "$(Get-Date -Format 'yyyyMMdd-HHmmss').json"
        @{
            Timestamp = Get-Date -Format "o"
            EventData = $EventData
            EventSource = $EventSource
            RetryCount = 0
            LastError = $_.Exception.Message
        } | ConvertTo-Json | Out-File $queueFile
        
        return $false
    }
}

function Process-Queue {
    $queuePath = "C:\GuardianFW\queue\"
    if (-not (Test-Path $queuePath)) {
        return
    }
    
    $queuedFiles = Get-ChildItem $queuePath -Filter "*.json" -ErrorAction SilentlyContinue
    if ($queuedFiles.Count -eq 0) {
        return
    }
    
    Write-GuardianLog -Message "Processing $($queuedFiles.Count) queued files..." -Level Info -Component "Queue"
    
    $processed = 0
    $failed = 0
    
    foreach ($file in $queuedFiles) {
        try {
            $queueEntry = Get-Content $file.FullName | ConvertFrom-Json
            
            # Check retry count
            if ($queueEntry.RetryCount -ge 3) {
                Write-GuardianLog -Message "Max retries reached for $($file.Name), moving to failed" -Level Warning -Component "Queue"
                Move-Item $file.FullName "$($file.DirectoryName)\failed\$($file.Name)" -Force -ErrorAction SilentlyContinue
                $failed++
                continue
            }
            
            # Try to send
            $success = Send-ToSplunk -EventData $queueEntry.EventData -EventSource $queueEntry.EventSource
            
            if ($success) {
                Remove-Item $file.FullName -Force
                $processed++
            } else {
                # Update retry count
                $queueEntry.RetryCount++
                $queueEntry.LastError = "Retry attempt $($queueEntry.RetryCount)"
                $queueEntry | ConvertTo-Json | Out-File $file.FullName -Force
            }
            
        } catch {
            Write-GuardianLog -Message "Error processing $($file.Name): $_" -Level Error -Component "Queue"
            $failed++
        }
    }
    
    Write-GuardianLog -Message "Queue processed: $processed succeeded, $failed failed" -Level Info -Component "Queue"
}

function Monitor-NetworkTraffic {
    # Simulate network traffic monitoring
    $trafficEvents = @(
        "TCP connection established from 192.168.1.100 to 8.8.8.8:443",
        "UDP packet from 10.0.0.5 to 1.1.1.1:53",
        "Blocked malicious IP: 185.220.101.74",
        "Allowed HTTP request to google.com",
        "Detected port scan from 203.0.113.5"
    )
    
    $randomEvent = Get-Random -InputObject $trafficEvents
    Write-GuardianLog -Message $randomEvent -Level Info -Component "Network"
    
    # Create event for Splunk
    $networkEvent = @{
        SourceIP = (Get-Random -InputObject @("192.168.1.100", "10.0.0.5", "203.0.113.5"))
        DestinationIP = (Get-Random -InputObject @("8.8.8.8", "1.1.1.1", "google.com"))
        Protocol = (Get-Random -InputObject @("TCP", "UDP", "HTTP", "HTTPS"))
        Action = (Get-Random -InputObject @("ALLOW", "BLOCK", "MONITOR"))
        Bytes = Get-Random -Minimum 64 -Maximum 1500
        Timestamp = Get-Date -Format "o"
    }
    
    return $networkEvent
}

# Main execution
try {
    # Load configuration
    if (Test-Path $ConfigPath) {
        $config = Get-Content $ConfigPath | ConvertFrom-Json
        Write-GuardianLog -Message "Configuration loaded successfully" -Level Info -Component "Monitor"
    } else {
        Write-GuardianLog -Message "Configuration file not found: $ConfigPath" -Level Error -Component "Monitor"
        exit 1
    }
    
    Write-GuardianLog -Message "Starting main monitoring loop..." -Level Info -Component "Monitor"
    
    # Main loop
    while ($Global:MonitorRunning) {
        $Global:CycleCount++
        
        Write-GuardianLog -Message "Cycle $Global:CycleCount starting..." -Level Debug -Component "Monitor"
        
        # 1. Check system health every 60 seconds
        $healthCheckInterval = New-TimeSpan -Seconds 60
        if ((Get-Date) - $Global:LastHealthCheck -gt $healthCheckInterval) {
            $systemHealth = Get-SystemHealth
            Write-GuardianLog -Message "System health: CPU=$($systemHealth.CPU)%, Memory=$($systemHealth.Memory)%, Uptime=$($systemHealth.Uptime)h" -Level Info -Component "Health"
            
            if ($config.Splunk.Enabled) {
                Send-ToSplunk -EventData $systemHealth -EventSource "guardianfw:health" -SplunkUrl $config.Splunk.Url | Out-Null
            }
            
            $Global:LastHealthCheck = Get-Date
        }
        
        # 2. Process queue every 30 seconds
        $queueInterval = New-TimeSpan -Seconds 30
        if ((Get-Date) - $Global:LastQueueProcess -gt $queueInterval) {
            Process-Queue
            $Global:LastQueueProcess = Get-Date
        }
        
        # 3. Monitor network traffic (simulated)
        $networkEvent = Monitor-NetworkTraffic
        if ($config.Splunk.Enabled) {
            Send-ToSplunk -EventData $networkEvent -EventSource "guardianfw:network" -SplunkUrl $config.Splunk.Url | Out-Null
        }
        
        # 4. Check log rotation
        if ($config.Logging.EnableLogRotation) {
            $logPath = "C:\GuardianFW\logs\"
            $logFiles = Get-ChildItem $logPath -Filter "*.log" -ErrorAction SilentlyContinue
            if ($logFiles) {
                $totalSizeMB = ($logFiles | Measure-Object -Property Length -Sum).Sum / 1MB
                if ($totalSizeMB -gt $config.Logging.MaxLogSizeMB) {
                    Write-GuardianLog -Message "Log size ($totalSizeMB MB) exceeds limit ($($config.Logging.MaxLogSizeMB) MB)" -Level Warning -Component "LogRotation"
                }
            }
        }
        
        # 5. Check if we should exit (for testing or duration limit)
        if ($TestMode -or ((Get-Date) - $Global:StartTime).TotalSeconds -gt $Duration) {
            Write-GuardianLog -Message "Monitor duration completed, stopping..." -Level Info -Component "Monitor"
            $Global:MonitorRunning = $false
        }
        
        # Sleep for configured interval
        $interval = 5  # seconds
        Start-Sleep -Seconds $interval
    }
    
} catch {
    Write-GuardianLog -Message "Monitor error: $_" -Level Error -Component "Monitor"
    Write-Host "[FATAL] Monitor crashed: $_" -ForegroundColor Red
    exit 1
}

Write-GuardianLog -Message "GuardianFW Monitor stopped after $Global:CycleCount cycles" -Level Info -Component "Monitor"
.Threads.Count } | Measure-Object -Sum).Sum
        Uptime = [math]::Round((New-TimeSpan -Start (Get-CimInstance Win32_OperatingSystem).LastBootUpTime -End (Get-Date)).TotalHours, 2)
    }
    
    return $health
}

function Send-ToSplunk {
    param(
        [Parameter(Mandatory=$true)]
        [object]$EventData,
        
        [Parameter(Mandatory=$true)]
        [string]$EventSource,
        
        [string]$SplunkUrl = "https://localhost:8088"
    )
    
    try {
        # Load token securely
        $tokenPath = "C:\GuardianFW\secure\splunk_token.xml"
        if (-not (Test-Path $tokenPath)) {
            Write-GuardianLog -Message "Splunk token file not found: $tokenPath" -Level Error -Component "Splunk"
            return $false
        }
        
        $secureToken = Import-Clixml -Path $tokenPath
        $token = [System.Runtime.InteropServices.Marshal]::PtrToStringAuto(
            [System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($secureToken)
        )
        
        # Prepare event
        $splunkEvent = @{
            time = Get-Date -Format "yyyy-MM-ddTHH:mm:ss.fffZ"
            host = $env:COMPUTERNAME
            source = $EventSource
            event = $EventData
        }
        
        $jsonBody = $splunkEvent | ConvertTo-Json -Depth 5
        
        # Prepare headers
        $headers = @{
            "Authorization" = "Splunk $token"
            "Content-Type" = "application/json"
        }
        
        # Send to Splunk
        $response = Invoke-RestMethod -Uri $SplunkUrl `
            -Method Post `
            -Headers $headers `
            -Body $jsonBody `
            -ErrorAction Stop
        
        Write-GuardianLog -Message "Event sent to Splunk successfully" -Level Debug -Component "Splunk"
        return $true
        
    } catch {
        Write-GuardianLog -Message "Failed to send to Splunk: $($_.Exception.Message)" -Level Warning -Component "Splunk"
        
        # Queue for retry
        $queuePath = "C:\GuardianFW\queue\"
        if (-not (Test-Path $queuePath)) {
            New-Item -ItemType Directory -Path $queuePath -Force | Out-Null
        }
        
        $queueFile = Join-Path $queuePath "$(Get-Date -Format 'yyyyMMdd-HHmmss').json"
        @{
            Timestamp = Get-Date -Format "o"
            EventData = $EventData
            EventSource = $EventSource
            RetryCount = 0
            LastError = $_.Exception.Message
        } | ConvertTo-Json | Out-File $queueFile
        
        return $false
    }
}

function Process-Queue {
    $queuePath = "C:\GuardianFW\queue\"
    if (-not (Test-Path $queuePath)) {
        return
    }
    
    $queuedFiles = Get-ChildItem $queuePath -Filter "*.json" -ErrorAction SilentlyContinue
    if ($queuedFiles.Count -eq 0) {
        return
    }
    
    Write-GuardianLog -Message "Processing $($queuedFiles.Count) queued files..." -Level Info -Component "Queue"
    
    $processed = 0
    $failed = 0
    
    foreach ($file in $queuedFiles) {
        try {
            $queueEntry = Get-Content $file.FullName | ConvertFrom-Json
            
            # Check retry count
            if ($queueEntry.RetryCount -ge 3) {
                Write-GuardianLog -Message "Max retries reached for $($file.Name), moving to failed" -Level Warning -Component "Queue"
                Move-Item $file.FullName "$($file.DirectoryName)\failed\$($file.Name)" -Force -ErrorAction SilentlyContinue
                $failed++
                continue
            }
            
            # Try to send
            $success = Send-ToSplunk -EventData $queueEntry.EventData -EventSource $queueEntry.EventSource
            
            if ($success) {
                Remove-Item $file.FullName -Force
                $processed++
            } else {
                # Update retry count
                $queueEntry.RetryCount++
                $queueEntry.LastError = "Retry attempt $($queueEntry.RetryCount)"
                $queueEntry | ConvertTo-Json | Out-File $file.FullName -Force
            }
            
        } catch {
            Write-GuardianLog -Message "Error processing $($file.Name): $_" -Level Error -Component "Queue"
            $failed++
        }
    }
    
    Write-GuardianLog -Message "Queue processed: $processed succeeded, $failed failed" -Level Info -Component "Queue"
}

function Monitor-NetworkTraffic {
    # Simulate network traffic monitoring
    $trafficEvents = @(
        "TCP connection established from 192.168.1.100 to 8.8.8.8:443",
        "UDP packet from 10.0.0.5 to 1.1.1.1:53",
        "Blocked malicious IP: 185.220.101.74",
        "Allowed HTTP request to google.com",
        "Detected port scan from 203.0.113.5"
    )
    
    $randomEvent = Get-Random -InputObject $trafficEvents
    Write-GuardianLog -Message $randomEvent -Level Info -Component "Network"
    
    # Create event for Splunk
    $networkEvent = @{
        SourceIP = (Get-Random -InputObject @("192.168.1.100", "10.0.0.5", "203.0.113.5"))
        DestinationIP = (Get-Random -InputObject @("8.8.8.8", "1.1.1.1", "google.com"))
        Protocol = (Get-Random -InputObject @("TCP", "UDP", "HTTP", "HTTPS"))
        Action = (Get-Random -InputObject @("ALLOW", "BLOCK", "MONITOR"))
        Bytes = Get-Random -Minimum 64 -Maximum 1500
        Timestamp = Get-Date -Format "o"
    }
    
    return $networkEvent
}

# Main execution
try {
    # Load configuration
    if (Test-Path $ConfigPath) {
        $config = Get-Content $ConfigPath | ConvertFrom-Json
        Write-GuardianLog -Message "Configuration loaded successfully" -Level Info -Component "Monitor"
    } else {
        Write-GuardianLog -Message "Configuration file not found: $ConfigPath" -Level Error -Component "Monitor"
        exit 1
    }
    
    Write-GuardianLog -Message "Starting main monitoring loop..." -Level Info -Component "Monitor"
    
    # Main loop
    while ($Global:MonitorRunning) {
        $Global:CycleCount++
        
        Write-GuardianLog -Message "Cycle $Global:CycleCount starting..." -Level Debug -Component "Monitor"
        
        # 1. Check system health every 60 seconds
        $healthCheckInterval = New-TimeSpan -Seconds 60
        if ((Get-Date) - $Global:LastHealthCheck -gt $healthCheckInterval) {
            $systemHealth = Get-SystemHealth
            Write-GuardianLog -Message "System health: CPU=$($systemHealth.CPU)%, Memory=$($systemHealth.Memory)%, Uptime=$($systemHealth.Uptime)h" -Level Info -Component "Health"
            
            if ($config.Splunk.Enabled) {
                Send-ToSplunk -EventData $systemHealth -EventSource "guardianfw:health" -SplunkUrl $config.Splunk.Url | Out-Null
            }
            
            $Global:LastHealthCheck = Get-Date
        }
        
        # 2. Process queue every 30 seconds
        $queueInterval = New-TimeSpan -Seconds 30
        if ((Get-Date) - $Global:LastQueueProcess -gt $queueInterval) {
            Process-Queue
            $Global:LastQueueProcess = Get-Date
        }
        
        # 3. Monitor network traffic (simulated)
        $networkEvent = Monitor-NetworkTraffic
        if ($config.Splunk.Enabled) {
            Send-ToSplunk -EventData $networkEvent -EventSource "guardianfw:network" -SplunkUrl $config.Splunk.Url | Out-Null
        }
        
        # 4. Check log rotation
        if ($config.Logging.EnableLogRotation) {
            $logPath = "C:\GuardianFW\logs\"
            $logFiles = Get-ChildItem $logPath -Filter "*.log" -ErrorAction SilentlyContinue
            if ($logFiles) {
                $totalSizeMB = ($logFiles | Measure-Object -Property Length -Sum).Sum / 1MB
                if ($totalSizeMB -gt $config.Logging.MaxLogSizeMB) {
                    Write-GuardianLog -Message "Log size ($totalSizeMB MB) exceeds limit ($($config.Logging.MaxLogSizeMB) MB)" -Level Warning -Component "LogRotation"
                }
            }
        }
        
        # 5. Check if we should exit (for testing or duration limit)
        if ($TestMode -or ((Get-Date) - $Global:StartTime).TotalSeconds -gt $Duration) {
            Write-GuardianLog -Message "Monitor duration completed, stopping..." -Level Info -Component "Monitor"
            $Global:MonitorRunning = $false
        }
        
        # Sleep for configured interval
        $interval = 5  # seconds
        Start-Sleep -Seconds $interval
    }
    
} catch {
    Write-GuardianLog -Message "Monitor error: $_" -Level Error -Component "Monitor"
    Write-Host "[FATAL] Monitor crashed: $_" -ForegroundColor Red
    exit 1
}

Write-GuardianLog -Message "GuardianFW Monitor stopped after $Global:CycleCount cycles" -Level Info -Component "Monitor"

