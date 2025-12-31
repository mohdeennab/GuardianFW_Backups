# GuardianFW High Availability Cluster
# Active-Passive or Active-Active configuration

class HACluster {
    [string]$Mode = "Active-Passive"  # Active-Passive or Active-Active
    [string]$CurrentRole = "Active"
    [System.Collections.Generic.List[string]]$ClusterNodes
    [hashtable]$HeartbeatConfig
    [int]$FailoverTimeout = 30  # seconds
    
    HACluster([string[]]$Nodes) {
        $this.ClusterNodes = [System.Collections.Generic.List[string]]::new($Nodes)
        $this.HeartbeatConfig = @{
            Interval = 5  # seconds
            Retries = 3
            Protocol = "UDP"
            Port = 694  # Linux-HA standard
        }
        
        $this.InitializeCluster()
    }
    
    [void] InitializeCluster() {
        # Elect primary node (lowest IP)
        $primary = $this.ClusterNodes | Sort-Object { [System.Net.IPAddress]::Parse($_) } | Select-Object -First 1
        
        if ($primary -eq $env:COMPUTERNAME -or $primary -eq (Get-NetIPAddress -AddressFamily IPv4).IPAddress) {
            $this.CurrentRole = "Active"
            Write-Host "This node is ACTIVE in the cluster" -ForegroundColor Green
            
            # Start VIP (Virtual IP)
            $this.Assign-VIP()
        } else {
            $this.CurrentRole = "Passive"
            Write-Host "This node is PASSIVE in the cluster" -ForegroundColor Yellow
            
            # Start heartbeat monitoring
            $this.Start-HeartbeatMonitor()
        }
    }
    
    [void] Start-HeartbeatMonitor() {
        # Monitor active node
        Start-Job -Name "HAHeartbeat" -ScriptBlock {
            param($ActiveNode, $Timeout)
            
            while ($true) {
                $alive = Test-Connection -ComputerName $ActiveNode -Count 1 -Quiet
                
                if (-not $alive) {
                    # Active node down - initiate failover
                    Write-Host "Active node failed! Initiating failover..." -ForegroundColor Red
                    
                    # Take over VIP
                    $this.Promote-ToActive()
                    
                    # Notify administrators
                    Send-HAFailoverAlert -OldActive $ActiveNode -NewActive $env:COMPUTERNAME
                    
                    break
                }
                
                Start-Sleep -Seconds $Timeout
            }
        } -ArgumentList ($this.ClusterNodes | Where-Object { $_ -ne $env:COMPUTERNAME }), $this.HeartbeatConfig.Interval
    }
    
    [void] Promote-ToActive() {
        $this.CurrentRole = "Active"
        
        # Take over VIP
        $this.Assign-VIP()
        
        # Start all services
        Start-GuardianFWServices
        
        # Sync configuration from shared storage
        $this.Sync-Configuration()
        
        Write-Host "Node promoted to ACTIVE role" -ForegroundColor Green
    }
    
    [void] Assign-VIP() {
        $vip = "10.0.0.100"  # Virtual IP for cluster
        
        # Remove VIP from all interfaces
        Get-NetIPAddress -IPAddress $vip -ErrorAction SilentlyContinue | Remove-NetIPAddress
        
        # Assign VIP to primary interface
        $primaryInterface = Get-NetAdapter | Where-Object { $_.Status -eq "Up" } | Select-Object -First 1
        
        if ($primaryInterface) {
            New-NetIPAddress -IPAddress $vip -PrefixLength 24 `
                -InterfaceIndex $primaryInterface.ifIndex -ErrorAction SilentlyContinue
            
            Write-Host "Virtual IP $vip assigned" -ForegroundColor Green
        }
    }
    
    [void] Sync-Configuration() {
        # Sync from shared storage (SAN, NAS, or cloud)
        $sharedConfig = "\\fileserver\GuardianFW\config\"
        
        if (Test-Path $sharedConfig) {
            Robocopy $sharedConfig "C:\GuardianFW\config\" /MIR /R:3 /W:5
            Write-Host "Configuration synchronized from shared storage" -ForegroundColor Green
        }
    }
}

# Load balancing for Active-Active
function Enable-LoadBalancing {
    param(
        [string]$LoadBalancerType = "WindowsNLB",
        [hashtable]$Config
    )
    
    switch ($LoadBalancerType) {
        "WindowsNLB" {
            # Windows Network Load Balancing
            Import-Module NetworkLoadBalancingClusters
            
            $nlb = Get-NlbCluster -ErrorAction SilentlyContinue
            if (-not $nlb) {
                # Create new NLB cluster
                New-NlbCluster -ClusterName "GuardianFW-Cluster" `
                    -ClusterPrimaryIP $Config.VIP `
                    -InterfaceName $Config.Interface `
                    -OperationMode $Config.Mode
                
                Write-Host "Windows NLB cluster created" -ForegroundColor Green
            }
            
            # Add this node to cluster
            Add-NlbClusterNode -HostName $env:COMPUTERNAME -InterfaceName $Config.Interface
        }
        "HAProxy" {
            # HAProxy configuration
            $haproxyConfig = @"
global
    log 127.0.0.1 local0
    maxconn 4096
    user haproxy
    group haproxy

defaults
    log     global
    mode    tcp
    option  tcplog
    retries 3
    timeout connect 5000ms
    timeout client 50000ms
    timeout server 50000ms

frontend guardianfw_frontend
    bind *:${Config.FrontendPort}
    default_backend guardianfw_backend

backend guardianfw_backend
    balance roundrobin
    option tcp-check
$(($Config.BackendNodes | ForEach-Object { "    server $_ $_ check port ${Config.HealthCheckPort}" }) -join "`n")
"@
            
            $haproxyConfig | Out-File "C:\GuardianFW\config\haproxy.cfg" -Encoding UTF8
        }
    }
}