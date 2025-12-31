# BEGIN TOPLEVEL TRY (GuardianFW TaskScheduler-safe)
try {
$ErrorActionPreference = "Stop"

$root = "C:\ProgramData\GuardianFW"

$stateDir  = "$root\state"
$stateFile = "$stateDir\autoheal.json"
$evDir     = "$root\evidence\autoheal"

New-Item -ItemType Directory -Path $stateDir -Force | Out-Null
New-Item -ItemType Directory -Path $evDir -Force | Out-Null

function Load-State {
  # Always return a HASHTABLE with all expected keys (so we can set fields safely)
  $default = @{
    state    = "ENFORCED"
    failures = 0
    last     = ""
    last_ts  = ""
  }

  if (Test-Path $stateFile) {
    try {
      $raw = Get-Content $stateFile -Raw
      if ($raw -and $raw.Trim().Length -gt 0) {
        $obj = $raw | ConvertFrom-Json

        # Merge: only override defaults if key exists
        if ($null -ne $obj.state)    { $default.state    = [string]$obj.state }
        if ($null -ne $obj.failures) { $default.failures = [int]$obj.failures }
        if ($null -ne $obj.last)     { $default.last     = [string]$obj.last }
        if ($null -ne $obj.last_ts)  { $default.last_ts  = [string]$obj.last_ts }
      }
    } catch {
      # If state is corrupt, keep defaults (and we’ll overwrite with valid json)
    }
  }

  return $default
}

function Save-State($s) {
  $s | ConvertTo-Json -Depth 4 | Out-File $stateFile -Encoding UTF8
}

$state = Load-State

# --- Verify ---
$verify = & "$root\engine\verify-firewall.ps1"

if ($verify.status -eq "OK") {
  $state.state = "ENFORCED"
  $state.failures = 0
  $state.last = "verify_ok"
  $state.last_ts = (Get-Date).ToString("s")
}
else {
  $state.state = "HEALING"
  $state.failures = [int]$state.failures + 1
  $state.last = "drift_detected"
  $state.last_ts = (Get-Date).ToString("s")

  # --- Heal ---
  try {
    $heal = & "$root\engine\heal-firewall.ps1"
    $state.last = "heal_ran"
  

    # reverify (so we can return to ENFORCED in same cycle)
    $reverify = & "$root\engine\verify-firewall.ps1"
    if ($reverify.status -eq "OK") {
      $state.state = "ENFORCED"
      $state.failures = 0
      $state.last = "heal_success_verify_ok"
    } else {
      $state.last = "heal_done_but_still_drift"
    }
} catch {
    $state.last = "heal_failed"
  }

  if ($state.failures -ge 3) {
    $state.state = "DEGRADED"
    $state.last = "degraded_after_retries"
  }
}

Save-State $state

$evidence = @{
  timestamp = (Get-Date).ToString("s")
  component = "firewall"
  state     = $state.state
  failures  = $state.failures
  last      = $state.last
  verify    = $verify
}

$evidence | ConvertTo-Json -Depth 8 |
  Out-File "$evDir\autoheal-firewall-$(Get-Date -Format yyyyMMdd-HHmmss).json" -Encoding UTF8

$state


  exit 0
} catch {
  try {
    \ = "C:\ProgramData\GuardianFW"
    \ = "\\evidence\autoheal"
    New-Item -ItemType Directory -Path \ -Force | Out-Null
    @{
      timestamp = (Get-Date).ToString("s")
      component = "firewall"
      state     = "ERROR"
      error     = (\.Exception.Message)
    } | ConvertTo-Json -Depth 6 | Out-File "\\autoheal-firewall-error-20251226-184430.json" -Encoding UTF8
  } catch {}
  exit 2
}
# END TOPLEVEL TRY
