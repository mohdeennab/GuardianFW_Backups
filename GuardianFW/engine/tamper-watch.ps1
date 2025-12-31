Set-StrictMode -Version Latest
$ErrorActionPreference="Stop"

$Root    = "C:\ProgramData\GuardianFW"
$Sealed  = Join-Path $Root "sealed"
$Fail    = Join-Path $Sealed "FAIL_SECURE.flag"
$Audit   = Join-Path $Root "logs\guardian-audit.jsonl"

# ---- Customize service/task names here ----
$Services = @("GuardianControl","GuardianAgent")
$Tasks    = @("GuardianFW-VerifyPolicy") # add more later, e.g. "GuardianFW-Health"

function Ensure-EventSource {
  if (-not [System.Diagnostics.EventLog]::SourceExists("GuardianFW")) {
    New-EventLog -LogName Application -Source "GuardianFW"
  }
}

function Write-Audit([string]$Event, [hashtable]$Data=@{}) {
  $dir = Split-Path $Audit
  if(!(Test-Path $dir)){ New-Item -ItemType Directory -Path $dir -Force | Out-Null }
  $rec = [pscustomobject]@{
    tsUtc = (Get-Date).ToUniversalTime().ToString("o")
    event = $Event
    data  = $Data
  }
  ($rec | ConvertTo-Json -Compress -Depth 6) | Add-Content -LiteralPath $Audit -Encoding UTF8
}

function Enter-FailSecure([string]$Reason, [hashtable]$Data=@{}) {
  if(!(Test-Path $Sealed)){ New-Item -ItemType Directory -Path $Sealed -Force | Out-Null }
  New-Item -ItemType File -Path $Fail -Force | Out-Null

  Ensure-EventSource
  Write-EventLog -LogName Application -Source "GuardianFW" -EventId 9101 -EntryType Error `
    -Message ("GuardianFW Anti-Tamper FAIL-SECURE: " + $Reason)

  Write-Audit "fail_secure_entered" (@{reason=$Reason} + $Data)
}

function Get-AclFingerprint([string]$Path) {
  if(!(Test-Path -LiteralPath $Path)){ return "missing" }
  $acl = Get-Acl -LiteralPath $Path
  $norm = $acl.Access | ForEach-Object {
    "$($_.IdentityReference.Value)|$($_.FileSystemRights)|$($_.AccessControlType)|$($_.IsInherited)|$($_.InheritanceFlags)|$($_.PropagationFlags)"
  } | Sort-Object
  return ($norm -join ";")
}

function Ensure-ServiceRunning([string]$Name) {
  $svc = Get-Service -Name $Name -ErrorAction SilentlyContinue
  if($null -eq $svc){
    Enter-FailSecure "service_missing" @{service=$Name}
    return
  }

  # If startup type disabled, re-enable to automatic (bank-grade self-heal)
  try {
    $wmi = Get-CimInstance Win32_Service -Filter "Name='$Name'"
    if($wmi.StartMode -eq "Disabled"){
      sc.exe config $Name start= auto | Out-Null
      Write-Audit "service_startmode_fixed" @{service=$Name; from="Disabled"; to="Auto"}
    }
  } catch {}

  if($svc.Status -ne "Running"){
    try {
      Start-Service -Name $Name -ErrorAction Stop
      Write-Audit "service_started" @{service=$Name}
    } catch {
      Enter-FailSecure "service_not_running" @{service=$Name; error=$_.Exception.Message}
    }
  }
}

function Ensure-TaskPresent([string]$Name) {
  $t = schtasks.exe /Query /TN $Name 2>$null
  if($LASTEXITCODE -ne 0){
    Enter-FailSecure "task_missing" @{task=$Name}
    return
  }
  # If disabled, we can re-enable via schtasks /Change
  if(($t | Out-String) -match "Disabled"){
    try {
      schtasks.exe /Change /TN $Name /ENABLE | Out-Null
      Write-Audit "task_enabled" @{task=$Name}
    } catch {
      Enter-FailSecure "task_disabled" @{task=$Name; error=$_.Exception.Message}
    }
  }
}

function Check-FirewallResetEvidence {
  # lightweight indicator: look for recent Defender Firewall policy reset events
  # If unavailable, this simply won't trigger.
  try {
    $since = (Get-Date).AddMinutes(-10)
    $ev = Get-WinEvent -FilterHashtable @{
      LogName = "Microsoft-Windows-Windows Firewall With Advanced Security/Firewall"
      StartTime = $since
    } -ErrorAction SilentlyContinue | Select-Object -First 20

    if($ev){
      # If any events exist, record; specific IDs differ by build, so just evidence-capture.
      Write-Audit "firewall_log_activity" @{count=($ev.Count)}
    }
  } catch {}
}

function Check-DnsResolverChanges {
  # Detect resolver changes (bank-grade)
  try {
    $ifaces = Get-DnsClientServerAddress -AddressFamily IPv4 -ErrorAction SilentlyContinue |
      Where-Object { $_.InterfaceAlias -and $_.ServerAddresses }

    foreach($i in $ifaces){
      # NOTE: Later we’ll compare against policy.json allowed_resolvers.
      # For now, just evidence and fail-secure if resolver becomes empty (often indicates tamper).
      if($i.ServerAddresses.Count -eq 0){
        Enter-FailSecure "dns_resolver_empty" @{iface=$i.InterfaceAlias}
      }
    }
  } catch {}
}

# ---- Baseline ACL fingerprints (first run stores baseline) ----
$AclBaselinePath = Join-Path $Sealed "acl-baseline.json"
$targets = @(
  (Join-Path $Root "engine"),
  (Join-Path $Root "policy"),
  (Join-Path $Root "keys"),
  (Join-Path $Root "logs"),
  (Join-Path $Root "sealed")
)

$baseline = @{}
if(Test-Path $AclBaselinePath){
  $baseline = Get-Content $AclBaselinePath -Raw -Encoding UTF8 | ConvertFrom-Json
} else {
  foreach($t in $targets){
    $baseline[$t] = Get-AclFingerprint $t
  }
  ($baseline | ConvertTo-Json -Depth 4) | Set-Content -LiteralPath $AclBaselinePath -Encoding UTF8
  Write-Audit "acl_baseline_created" @{path=$AclBaselinePath}
}

# ---- Checks ----
Ensure-EventSource

foreach($s in $Services){ Ensure-ServiceRunning $s }
foreach($n in $Tasks){ Ensure-TaskPresent $n }

# ACL tamper detection
foreach($t in $targets){
  $cur = Get-AclFingerprint $t
  $old = $baseline.$t
  if($null -eq $old){ continue }
  if($cur -ne $old){
    Enter-FailSecure "acl_changed" @{target=$t}
  }
}

Check-DnsResolverChanges
Check-FirewallResetEvidence

# If we made it here: OK
Write-Audit "tamper_watch_ok" @{services=$Services; tasks=$Tasks}

