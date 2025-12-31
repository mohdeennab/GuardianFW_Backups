$script:EngineRoot = if ($PSScriptRoot) { $PSScriptRoot } else { "C:\ProgramData\GuardianFW\engine" }
. "$script:EngineRoot\GuardianFW-Common.ps1"
. "$script:EngineRoot\GuardianFW-Policy.ps1"
. "$script:EngineRoot\GuardianFW-State.ps1"
. "$script:EngineRoot\GuardianFW-Enforce.ps1"

function Enter-GFSingleInstance {
  param([string] $Name = "Global\GuardianFW.PhaseX")
  $created = $false
  $m = New-Object System.Threading.Mutex($true, $Name, [ref]$created)
  if (-not $created) { return $null }
  return $m
}

function Run-GuardianFWPhaseX {
  Ensure-GFDirs
  $mutex = Enter-GFSingleInstance
  if ($null -eq $mutex) {
    Write-GFLog -Path $GFLogGuardian -Level "INFO" -Message "PhaseX: another instance is running. Exiting."
    return 0
  }

  try {
    $policy = Get-GFPolicy

    # Ensure policy file exists on disk for your API mode (optional)
    if (!(Test-Path $GFPolicy)) { Write-JsonFile -Path $GFPolicy -Obj $policy }

    Set-GFState -State "HEALING" -Reason "policy_enforcement"
    $ok = Invoke-GFEnforcePolicy -Policy $policy

    if ($ok) {
      Set-GFState -State "ENFORCED" -Reason "policy_ok"
      Save-GFLastGoodState -Why "policy_ok"
      Write-GFLog -Path $GFLogAutoHeal -Level "INFO" -Message "PhaseX enforcement success."
      return 0
    } else {
      Inc-GFCounter -Name "heal_attempts" | Out-Null
      Set-GFState -State "DEGRADED" -Reason "policy_apply_failed"
      $cd = [int]$policy.self_protection.cooldown_seconds
      Set-GFState -State "COOLDOWN" -Reason "cooldown_${cd}s"
      Write-GFLog -Path $GFLogAutoHeal -Level "WARN" -Message "PhaseX enforcement failed; cooldown $cd seconds."
      return 10
    }
  }
  catch {
    Write-GFLog -Path $GFLogGuardian -Level "ERR" -Message ("PhaseX fatal: " + $_.Exception.Message)
    return 50
  }
  finally {
    if ($mutex) { $mutex.ReleaseMutex() | Out-Null; $mutex.Dispose() }
  }
}

exit (Run-GuardianFWPhaseX)
