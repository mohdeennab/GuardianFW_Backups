$ErrorActionPreference = "Stop"

$root = "C:\ProgramData\GuardianFW"
$verify = & "$root\engine\verify-firewall.ps1"

if ($verify.status -eq "OK") {
  return @{ status="OK"; action="none" }
}

if (Test-Path "$root\engine\wfp-apply.ps1") {
  & "$root\engine\wfp-apply.ps1"
}

if (Test-Path "$root\engine\doh-enforcement.ps1") {
  & "$root\engine\doh-enforcement.ps1"
}

@{
  timestamp = (Get-Date).ToString("s")
  action    = "heal"
  drift     = $verify
}
