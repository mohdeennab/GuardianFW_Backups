param(
  [Parameter(Mandatory=$true)][string]$IntentId,
  [string]$Decision = "BLOCK",
  [string]$ProcessName = "",
  [string]$ProcessPath = "",
  [string]$UserName = "",
  [string]$Protocol = "",
  [int]$RemotePort = 0,
  [string]$Destination = "",
  [string]$EnforcementRule = "",
  [string[]]$Justification = @()
)

$ErrorActionPreference="Stop"


# Normalize Justification to string[] always
$Justification = @(
  foreach($x in @($Justification)){
    $t = (""+$x).Trim()
    if($t){ $t }
  }
)
if ($null -eq $Justification) { $Justification = @() }
$Justification = @($Justification | ForEach-Object { [string]$_ })

$root="C:\ProgramData\GuardianFW"
$decisionId = [guid]::NewGuid().ToString("D")
$shortId = ($decisionId -replace "-","").Substring(0,6)
$evDir = Join-Path $root "evidence\decisions"
New-Item -ItemType Directory -Path $evDir -Force | Out-Null
$fn = "decision-{0}-{1}.json" -f (Get-Date -Format yyyyMMdd-HHmmss), $shortId
$outPath = Join-Path $evDir $fn
$intentPath="$root\policies\intent-map.json"

$intent = $null
try {
  $imap = Get-Content $intentPath -Raw | ConvertFrom-Json
  $intent = $imap.intents | Where-Object { $_.id -eq $IntentId } | Select-Object -First 1
} catch {}

$repeat = 0
$risk = & "$root\engine\risk-score.ps1" -IntentId $IntentId -ProcessPath $ProcessPath -RepeatCount $repeat
# ---- Force Justification to string[] (robust) ----
if ($null -eq $Justification) { $Justification = @() }

# Ensure array first
$Justification = @($Justification)

# If it came in as a single comma-joined string (very common), split it
if ($Justification.Count -eq 1) {
  $one = [string]$Justification[0]
  if ($one -match ',') {
    $Justification = @($one -split '\s*,\s*')
  }
}

# Trim + drop empties
$Justification = @(
  foreach($x in $Justification){
    $v = (""+$x).Trim()
    if($v){ $v }
  }
)
# -----------------------------------------------

# --------------------------------

$rec = @{
  decision_id = $decisionId
timestamp = (Get-Date).ToString("s")

out_path = $outPath
out_file = [System.IO.Path]::GetFileName($outPath)
  decision  = $Decision
  intent_id = $IntentId
  intent_category = if($intent){[string]$intent.category}else{""}
  severity  = if($intent){[string]$intent.severity}else{""}
  risk_score = [int]$risk
  confidence = "HIGH"
  subject = @{ process=$ProcessName; path=$ProcessPath; user=$UserName }
  network = @{ protocol=$Protocol; remote_port=$RemotePort; destination=$Destination }
  enforcement = @{ method="WFP + Firewall"; rule=$EnforcementRule }
  justification = $Justification
}

$rec | ConvertTo-Json -Depth 10 | Out-File $outPath -Encoding UTF8
$rec






