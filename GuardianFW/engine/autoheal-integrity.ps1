$ErrorActionPreference="Stop"
$root="C:\ProgramData\GuardianFW"
$evDir="$root\evidence\integrity"
New-Item -ItemType Directory -Path $evDir -Force | Out-Null

$verify = & "$root\engine\verify-integrity.ps1"

$actions=@()

foreach($d in $verify.drift){
  if($d.type -eq "task" -and $d.issue -eq "disabled"){
    schtasks /Change /TN $d.task /ENABLE | Out-Null
    $actions += @{ action="enable_task"; task=$d.task }
  }
  if($d.type -eq "firewall_profile" -and $d.issue -eq "disabled"){
    Set-NetFirewallProfile -Profile $d.profile -Enabled True
    $actions += @{ action="enable_firewall_profile"; profile=$d.profile }
  }
}

$result=@{
  timestamp=(Get-Date).ToString("s")
  component="integrity"
  verify=$verify
  actions=$actions
  note="File hash drift is logged but not auto-restored (installer should repair)."
}

$result | ConvertTo-Json -Depth 12 | Out-File "$evDir\autoheal-$(Get-Date -Format yyyyMMdd-HHmmss).json" -Encoding UTF8

# Exit codes for scheduler clarity
if($verify.status -eq "OK"){ exit 0 } else { exit 1 }
