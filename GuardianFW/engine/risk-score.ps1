param(
  [Parameter(Mandatory=$true)][string]$IntentId,
  [string]$ProcessPath = "",
  [int]$RepeatCount = 0
)
$ErrorActionPreference="Stop"

$score = 0
switch ($IntentId) {
  "INTENT_DOH_EVASION" { $score += 40 }
  "INTENT_QUIC_BYPASS" { $score += 20 }
  default { $score += 10 }
}

if ($RepeatCount -gt 1) { $score += 15 }
if ($ProcessPath -and $ProcessPath -notlike "C:\Program Files*") { $score += 10 }
if ($ProcessPath -match "(?i)chrome|edge|firefox") { $score += 5 }

if ($score -gt 100) { $score = 100 }
$score
