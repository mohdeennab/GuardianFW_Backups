function Normalize-GfwBlockText([string]$t){
  if($null -eq $t){ return "" }
  # Normalize EOL, then trim ONLY trailing whitespace/newlines
  $t = $t -replace "`r?`n","`r`n"
  return ($t.TrimEnd() + "`r`n")
}
$ErrorActionPreference="Stop"
Set-StrictMode -Version Latest

Import-Module "C:\ProgramData\GuardianFW\engine\Guardian.DnsDrift.psm1" -Force

function Get-GfwDnsPolicyPath { "C:\ProgramData\GuardianFW\policy\dns-policy.json" }

function Get-GfwDnsPolicy {
  $p = Get-GfwDnsPolicyPath
  if(-not (Test-Path $p)){ throw "DNS policy missing: $p" }
  (Get-Content -LiteralPath $p -Raw -Encoding UTF8) | ConvertFrom-Json
}

function Build-ExpectedManagedBlock($policy){
  $lines = New-Object System.Collections.Generic.List[string]
  $lines.Add("# --- GuardianFW managed entries ---")
  $lines.Add("# policy_version=" + [string]$policy.version)
  foreach($d in @($policy.block)){
    if([string]::IsNullOrWhiteSpace($d)){ continue }
    $lines.Add("0.0.0.0 " + $d.Trim().ToLower())
  }
  $lines.Add("# --- End GuardianFW managed entries ---")
  return ($lines -join "`r`n") + "`r`n"
}

function Check-GfwDnsDrift {
  $policy   = Get-GfwDnsPolicy
  $expected = Build-ExpectedManagedBlock $policy

  $curText = Get-GfwManagedBlockText
  $curHash = (Get-GfwTextSha256 (Normalize-GfwBlockText $curText))
  $expHash = (Get-GfwTextSha256 (Normalize-GfwBlockText $expected))

  $drift = ($curHash -ne $expHash)

  return @{
    drift          = $drift
    reason         = $(if($drift){"MISMATCH_EXPECTED"}else{"MATCH_EXPECTED"})
    current_hash   = $curHash
    expected_hash  = $expHash
    policy_version = [int]$policy.version
  }
}

