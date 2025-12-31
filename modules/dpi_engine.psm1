# GuardianFW Deep Packet Inspection
# Layer 7 protocol analysis

class DeepPacketInspector {
    [hashtable]$ProtocolSignatures
    [System.Collections.Generic.List[object]]$ThreatPatterns
    [bool]$EnableSSLInspection = $false
    
    DeepPacketInspector() {
        $this.Load-Signatures()
        $this.Load-ThreatPatterns()
    }
    
    [void] Load-Signatures() {
        $this.ProtocolSignatures = @{
            "HTTP" = @{
                Ports = @(80, 8080, 8000)
                Pattern = "^GET|POST|PUT|DELETE|HEAD|OPTIONS"
                Parser = "Parse-HTTP"
            }
            "HTTPS" = @{
                Ports = @(443, 8443)
                Pattern = "^\x16\x03"  # TLS handshake
                Parser = "Parse-TLS"
            }
            "DNS" = @{
                Ports = @(53)
                Pattern = "^\x00[\x01-\x0F]"
                Parser = "Parse-DNS"
            }
            "SSH" = @{
                Ports = @(22)
                Pattern = "^SSH-"
                Parser = "Parse-SSH"
            }
            "RDP" = @{
                Ports = @(3389)
                Pattern = "^\x03\x00\x00"
                Parser = "Parse-RDP"
            }
        }
    }
    
    [object] Inspect-Packet([byte[]]$Packet) {
        $inspectionResult = @{
            Protocol = "Unknown"
            RiskLevel = "Low"
            Threats = @()
            Action = "Allow"
            Metadata = @{}
        }
        
        # Identify protocol
        foreach ($proto in $this.ProtocolSignatures.GetEnumerator()) {
            foreach ($port in $proto.Value.Ports) {
                if ($Packet[0] -eq $port -or $Packet[1] -eq $port) {
                    $inspectionResult.Protocol = $proto.Key
                    
                    # Parse protocol-specific data
                    $parser = $proto.Value.Parser
                    $parsedData = & $parser -Packet $Packet
                    $inspectionResult.Metadata = $parsedData
                    
                    # Check for threats
                    $threats = $this.Detect-Threats($parsedData, $proto.Key)
                    if ($threats.Count -gt 0) {
                        $inspectionResult.Threats = $threats
                        $inspectionResult.RiskLevel = "High"
                        $inspectionResult.Action = "Block"
                    }
                    
                    break
                }
            }
        }
        
        return $inspectionResult
    }
    
    [object[]] Detect-Threats([object]$ParsedData, [string]$Protocol) {
        $detectedThreats = @()
        
        foreach ($pattern in $this.ThreatPatterns) {
            if ($ParsedData.Content -match $pattern.Regex) {
                $detectedThreats += @{
                    Type = $pattern.Type
                    Description = $pattern.Description
                    Severity = $pattern.Severity
                    Match = $Matches[0]
                }
                
                # Update threat intelligence
                $this.Update-ThreatIntel($pattern, $ParsedData.SourceIP)
            }
        }
        
        return $detectedThreats
    }
    
    [void] Enable-SSLInspection([string]$CA Certificate) {
        # MITM SSL inspection (requires CA certificate)
        $this.EnableSSLInspection = $true
        
        # Install CA certificate
        Import-Certificate -FilePath $CA Certificate -CertStoreLocation "Cert:\LocalMachine\Root"
        
        # Configure SSL interception
        $this.Configure-SSLInterception()
    }
    
    [object] Parse-HTTP([byte[]]$Packet) {
        $content = [System.Text.Encoding]::UTF8.GetString($Packet)
        
        $parsed = @{
            Method = $content.Split(" ")[0]
            URL = $content.Split(" ")[1]
            Headers = @{}
            Body = ""
            ContentType = ""
        }
        
        # Parse headers
        $lines = $content -split "`r`n"
        foreach ($line in $lines) {
            if ($line -match "^([^:]+):\s*(.+)$") {
                $parsed.Headers[$Matches[1]] = $Matches[2]
                
                if ($Matches[1] -eq "Content-Type") {
                    $parsed.ContentType = $Matches[2]
                }
            }
        }
        
        # Extract body
        $bodyStart = $content.IndexOf("`r`n`r`n")
        if ($bodyStart -gt 0) {
            $parsed.Body = $content.Substring($bodyStart + 4)
        }
        
        return $parsed
    }
}

# Web Application Firewall (WAF) Module
function Enable-WAF {
    param(
        [hashtable]$Rules
    )
    
    $wafRules = @{
        "SQL Injection" = @{
            Pattern = "(\%27)|(\')|(\-\-)|(\%23)|(#)"
            Action = "Block"
            LogOnly = $false
        }
        "XSS Attack" = @{
            Pattern = "((\%3C)|<)((\%2F)|\/)*[a-z0-9\%]+((\%3E)|>)"
            Action = "Block"
            LogOnly = $false
        }
        "Path Traversal" = @{
            Pattern = "(\.\.\/)|(\.\.\\)"
            Action = "Block"
            LogOnly = $false
        }
        "Command Injection" = @{
            Pattern = ";|\|(\||\&)|`$\(|`\(|\|\||\&\&"
            Action = "Block"
            LogOnly = $false
        }
    }
    
    # Merge custom rules
    foreach ($rule in $Rules.GetEnumerator()) {
        $wafRules[$rule.Key] = $rule.Value
    }
    
    return $wafRules
}