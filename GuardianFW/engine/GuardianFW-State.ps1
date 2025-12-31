$script:EngineRoot = if ($PSScriptRoot) { $PSScriptRoot } else { "C:\ProgramData\GuardianFW\engine" }
. "$script:EngineRoot\GuardianFW-Common.ps1"

function Get-GFCurrentState {
  $d = Read-JsonFile -Path $GFStateCurrent -Default $null
  if ($null -eq $d -or -not $d.state) {
    return [pscustomobject]@{ state="INIT"; since=(Get-UTCIso); reason="boot" }
  }
  return $d
}

function Set-GFState {
  param(
    [Parameter(Mandatory)]
    [ValidateSet("INIT","ENFORCED","DEGRADED","HEALING","COOLDOWN","LOCKDOWN")]
    [string] $State,
    [string] $Reason = ""
  )
  $obj = [pscustomobject]@{
    state  = $State
    since  = (Get-UTCIso)
    reason = $Reason
  }
  Write-JsonFile -Path $GFStateCurrent -Obj $obj
  Write-GFLog -Path $GFLogGuardian -Level "INFO" -Message "[STATE] -> $State ($Reason)"
}

function Get-GFCounters {
  $def = [pscustomobject]@{
    heal_attempts = 0
    last_heal     = $null
    tamper_events = 0
    last_tamper   = $null
  }
  return (Read-JsonFile -Path $GFCounters -Default $def)
}

function Set-GFCounters { param([Parameter(Mandatory)] [object] $Obj) Write-JsonFile -Path $GFCounters -Obj $Obj }

function Inc-GFCounter {
  param([Parameter(Mandatory)] [string] $Name)
  $c = Get-GFCounters
  if ($null -eq $c.$Name) { Add-Member -InputObject $c -NotePropertyName $Name -NotePropertyValue 0 -Force }
  $c.$Name = [int]$c.$Name + 1
  if ($Name -eq "heal_attempts") { $c.last_heal = (Get-UTCIso) }
  if ($Name -eq "tamper_events") { $c.last_tamper = (Get-UTCIso) }
  Set-GFCounters -Obj $c
  return $c
}

function Save-GFLastGoodState {
  param([string] $Why="ok")
  $s = Get-GFCurrentState
  $obj = [pscustomobject]@{
    state = $s.state
    since = $s.since
    saved = (Get-UTCIso)
    why   = $Why
  }
  Write-JsonFile -Path $GFStateLastGood -Obj $obj
}
