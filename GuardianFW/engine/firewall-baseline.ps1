$ErrorActionPreference = "Stop"

$root = "C:\ProgramData\GuardianFW"
$intDir = "$root\integrity"
$evDir  = "$root\evidence\firewall"

New-Item -ItemType Directory -Path $intDir -Force | Out-Null
New-Item -ItemType Directory -Path $evDir  -Force | Out-Null

$rules = Get-NetFirewallRule |
  Where-Object { $_.DisplayName -like "GuardianFW*" } |
  ForEach-Object {
    $r = $_
    $pf = Get-NetFirewallPortFilter -AssociatedNetFirewallRule $r -ErrorAction SilentlyContinue
    $af = Get-NetFirewallApplicationFilter -AssociatedNetFirewallRule $r -ErrorAction SilentlyContinue

    @{
      Name       = $r.DisplayName
      Direction  = $r.Direction
      Action     = $r.Action
      Enabled    = $r.Enabled
      Profile    = $r.Profile
      Program    = $af.Program
      Protocol   = $pf.Protocol
      LocalPort  = $pf.LocalPort
      RemotePort = $pf.RemotePort
    }
  }

$baseline = @{
  timestamp = (Get-Date).ToString("s")
  ruleCount = $rules.Count
  rules     = $rules
}

$baseline | ConvertTo-Json -Depth 5 |
  Out-File "$intDir\firewall-baseline.json" -Encoding UTF8
