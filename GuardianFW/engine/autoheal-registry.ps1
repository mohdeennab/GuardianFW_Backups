$ErrorActionPreference="Stop"
$root="C:\ProgramData\GuardianFW"
$evDir="$root\evidence\registry"
New-Item -ItemType Directory -Path $evDir -Force | Out-Null

$verify = & "$root\engine\verify-registry.ps1"

if ($verify.status -eq "DRIFT") {
  $heal = & "$root\engine\heal-registry.ps1" 2>&1 | Out-String
  $post = & "$root\engine\verify-registry.ps1"

  $e = @{
    timestamp = (Get-Date).ToString("s")
    component = "registry"
    action    = "heal_attempted"
    verify    = $verify
    heal_out  = $heal
    post      = $post
  }
  $e | ConvertTo-Json -Depth 12 |
    Out-File "$evDir\autoheal-registry-$(Get-Date -Format yyyyMMdd-HHmmss).json" -Encoding UTF8

  if ($post.status -ne "OK") { exit 2 } else { exit 0 }
}

$e = @{
  timestamp = (Get-Date).ToString("s")
  component = "registry"
  action    = "no_drift"
  verify    = $verify
}
$e | ConvertTo-Json -Depth 8 |
  Out-File "$evDir\autoheal-registry-$(Get-Date -Format yyyyMMdd-HHmmss).json" -Encoding UTF8

exit 0
