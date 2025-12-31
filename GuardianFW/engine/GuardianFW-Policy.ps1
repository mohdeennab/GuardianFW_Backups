$script:EngineRoot = if ($PSScriptRoot) { $PSScriptRoot } else { "C:\ProgramData\GuardianFW\engine" }
. "$script:EngineRoot\GuardianFW-Common.ps1"

function Get-GFPolicy {
  $default = [pscustomobject]@{
    version = "1.0"
    dns = [pscustomobject]@{
      block_plain_dns   = $false
      block_doh         = $true
      block_dot         = $true
      allowed_resolvers = @("127.0.0.1")
    }
    network = [pscustomobject]@{
      block_quic          = $true
      allow_loopback_only = $true
    }
    self_protection = [pscustomobject]@{
      autoheal          = $true
      tamper_response  = "lockdown"  # log|heal|lockdown
      cooldown_seconds = 300
    }
    logging = [pscustomobject]@{
      evidence_level = "verbose"     # minimal|verbose
    }
    control_plane = [pscustomobject]@{
      mode        = "powershell"     # powershell|api
      api_base    = "http://127.0.0.1:5050"
      health_path = "/health"
      sync_path   = "/sync"
      timeout_sec = 3
    }
  }

  $p = Read-JsonFile -Path $GFPolicy -Default $default
  return $p
}
