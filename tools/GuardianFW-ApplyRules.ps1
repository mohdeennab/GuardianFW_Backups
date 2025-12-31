param(
  [string]$ApiBase = "http://127.0.0.1:5051",
  [string]$HostsPath = "$env:WINDIR\System32\drivers\etc\hosts",
  [switch]$DryRun
)

$StartMarker = "# --- GuardianFW managed entries ---"
$EndMarker   = "# --- End GuardianFW managed entries ---"

function Get-Rules {
  try {
    $url = "$ApiBase/rules/"
    return Invoke-RestMethod -Method Get -Uri $url -TimeoutSec 5
  } catch {
    throw "Cannot reach API at $ApiBase. Error: $($_.Exception.Message)"
  }
}

function Clean-HostsBlocks([string[]]$lines) {
  $out = New-Object System.Collections.Generic.List[string]
  $inBlock = $false
  foreach ($line in $lines) {
    if ($line.Trim() -eq $StartMarker) { $inBlock = $true; continue }
    if ($line.Trim() -eq $EndMarker)   { $inBlock = $false; continue }
    if (-not $inBlock) { $out.Add($line) }
  }
  return $out
}

function Build-BlockDomains($rules) {
  # Only enabled BLOCK rules, normalize domains, generate common variants
  $domains = New-Object System.Collections.Generic.HashSet[string] ([StringComparer]::OrdinalIgnoreCase)

  foreach ($r in $rules) {
    if ($null -eq $r) { continue }
    if ($r.enabled -ne $true) { continue }
    if (($r.action | Out-String).Trim().ToUpper() -ne "BLOCK") { continue }

    $d = ($r.domain | Out-String).Trim().ToLower()
    if ([string]::IsNullOrWhiteSpace($d)) { continue }

    # keep domain itself
    [void]$domains.Add($d)

    # add www only if it makes sense
    if ($d -notlike "www.*" -and $d -notlike "apis.*") {
      [void]$domains.Add("www.$d")
    }
  }

  return $domains
}

function Apply-Hosts([string]$hostsPath, $domains) {
  if (-not (Test-Path $hostsPath)) { throw "Hosts file not found: $hostsPath" }

  $backup = "$hostsPath.bak_guardianfw_apply_{0}.txt" -f (Get-Date -Format "yyyyMMdd_HHmmss")
  Copy-Item $hostsPath $backup -Force

  $lines = Get-Content $hostsPath
  $base  = Clean-HostsBlocks $lines

  $base.Add("") | Out-Null
  $base.Add($StartMarker) | Out-Null

  foreach ($d in ($domains | Sort-Object)) {
    $base.Add("0.0.0.0 $d") | Out-Null
  }

  $base.Add($EndMarker) | Out-Null

  if ($DryRun) {
    Write-Host "DRY RUN: would write hosts + backup at: $backup" -ForegroundColor Yellow
    return
  }

  Set-Content -Path $hostsPath -Value $base -Encoding ASCII
  ipconfig /flushdns | Out-Null

  Write-Host "Applied $(($domains | Measure-Object).Count) blocked domains to hosts." -ForegroundColor Green
  Write-Host "Backup: $backup" -ForegroundColor DarkGray
}

# --- main ---
$rules = Get-Rules
$domains = Build-BlockDomains $rules
Apply-Hosts -hostsPath $HostsPath -domains $domains
