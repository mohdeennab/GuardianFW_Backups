param(
  [string]$PolicyPath = "C:\ProgramData\GuardianFW\policy\dns-policy.json"
)
$ErrorActionPreference="Stop"
Set-StrictMode -Version Latest

if(!(Test-Path -LiteralPath $PolicyPath)){ throw "DNS policy missing: $PolicyPath" }

$pol = (Get-Content -LiteralPath $PolicyPath -Raw -Encoding UTF8) | ConvertFrom-Json

function Require($ok,[string]$msg){ if(-not $ok){ throw "DNS_POLICY_INVALID: $msg" } }

Require ($null -ne $pol.version) "version missing"
Require ($pol.mode) "mode missing"
$mode = ([string]$pol.mode).ToLower()
Require ($mode -in @("enforce","audit","monitor")) "mode must be enforce|audit|monitor"

if($null -ne $pol.block){
  foreach($d in @($pol.block)){
    if([string]::IsNullOrWhiteSpace([string]$d)){ continue }
    $s=[string]$d
    Require ($s -notmatch '\s') "domain contains whitespace: $s"
  }
}

"OK: dns policy validated"
exit 0
