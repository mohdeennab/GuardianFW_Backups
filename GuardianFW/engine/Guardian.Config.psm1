# Guardian.Config.psm1
Set-StrictMode -Version Latest

function Get-GfwConfigPath { "C:\ProgramData\GuardianFW\config.json" }
function Get-GfwBaselinePath { "C:\ProgramData\GuardianFW\baseline\baseline.sha256" }

function Get-GfwFileSha256([string]$Path){
  if(-not (Test-Path $Path)){ return $null }
  (Get-FileHash -Algorithm SHA256 -LiteralPath $Path).Hash.ToLower()
}

function Test-GfwBaseline {
  $baseline = Get-GfwBaselinePath
  if(-not (Test-Path $baseline)){ return @{ ok=$false; reason="BASELINE_MISSING" } }

  $lines = Get-Content -LiteralPath $baseline -Encoding UTF8 | Where-Object { $_ -and ($_ -notmatch '^\s*#') }
  foreach($ln in $lines){
    if($ln -match '^MISSING\s+\*(.+)$'){
      return @{ ok=$false; reason="BASELINE_HAS_MISSING"; file=$matches[1] }
    }
    if($ln -match '^([0-9a-f]{64})\s+\*(.+)$'){
      $expected = $matches[1]
      $file = $matches[2]
      if(-not (Test-Path $file)){ return @{ ok=$false; reason="FILE_MISSING"; file=$file } }
      $actual = Get-GfwFileSha256 $file
      if($actual -ne $expected){ return @{ ok=$false; reason="HASH_MISMATCH"; file=$file; expected=$expected; actual=$actual } }
    }
  }
  return @{ ok=$true }
}

function Get-GfwConfig {
  $p = Get-GfwConfigPath
  if(-not (Test-Path $p)){ throw "config.json not found: $p" }
  (Get-Content -LiteralPath $p -Raw -Encoding UTF8) | ConvertFrom-Json
}

Export-ModuleMember -Function Test-GfwBaseline,Get-GfwConfig
