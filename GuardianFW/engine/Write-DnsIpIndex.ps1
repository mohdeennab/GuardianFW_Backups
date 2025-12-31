Set-StrictMode -Version Latest
$ErrorActionPreference="Stop"

$root="C:\ProgramData\GuardianFW"
$idx = Join-Path $root "cache\dns-ip-index.ndjson"
$mutex="Global\GuardianFW_DnsCache_Mutex"

function Append-NdjsonLine([string]$path, [string]$line){
  New-Item -ItemType Directory -Path (Split-Path $path) -Force | Out-Null
  $bytes = [System.Text.Encoding]::UTF8.GetBytes($line + "`n")
  $fs = [System.IO.File]::Open($path,[System.IO.FileMode]::Append,[System.IO.FileAccess]::Write,[System.IO.FileShare]::Read)
  try { $fs.Write($bytes,0,$bytes.Length) } finally { $fs.Dispose() }
}

function With-Mutex([string]$Name,[scriptblock]$Body,[int]$TimeoutMs=1500){
  $m = New-Object System.Threading.Mutex($false,$Name)
  $ok=$false
  try { $ok=$m.WaitOne($TimeoutMs); if(-not $ok){throw "Mutex timeout: $Name"}; & $Body }
  finally { if($ok){$m.ReleaseMutex()|Out-Null}; $m.Dispose() }
}

function Write-DnsIpIndex {
  param(
    [Parameter(Mandatory)][string]$Domain,
    [Parameter(Mandatory)][string[]]$AnswerIPs,
    [string]$TsUtcIso = ((Get-Date).ToUniversalTime().ToString("o")),
    [int]$ProcPid,
    [string]$ProcName,
    [string]$Resolver,
    [string]$QType="A"
  )

  $rows = foreach($ip in $AnswerIPs){
    [pscustomobject]@{
      ts=$TsUtcIso; ip=$ip; domain=$Domain; pid=$ProcPid; proc=$ProcName; resolver=$Resolver; qtype=$QType
    } | ConvertTo-Json -Compress
  }

  With-Mutex -Name $mutex -Body {
    foreach($r in $rows){ Append-NdjsonLine -path $idx -line $r }
  }
}
