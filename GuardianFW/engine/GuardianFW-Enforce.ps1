$script:EngineRoot = if ($PSScriptRoot) { $PSScriptRoot } else { "C:\ProgramData\GuardianFW\engine" }
. "$script:EngineRoot\GuardianFW-Common.ps1"
. "$script:EngineRoot\GuardianFW-Policy.ps1"
. "$script:EngineRoot\GuardianFW-State.ps1"

function Invoke-GFEnforcePolicy {
  param([object] $Policy)

  $mode = "powershell"
  if ($Policy.control_plane -and $Policy.control_plane.mode) { $mode = [string]$Policy.control_plane.mode }

  if ($mode -ieq "api") { return Invoke-GFEnforcePolicy_Api -Policy $Policy }
  else { return Invoke-GFEnforcePolicy_PowerShell -Policy $Policy }
}

function Invoke-GFEnforcePolicy_Api {
  param([object] $Policy)

  $base = [string]$Policy.control_plane.api_base
  if ([string]::IsNullOrWhiteSpace($base)) { throw "control_plane.api_base missing" }

  $healthPath = if ($Policy.control_plane.health_path) { [string]$Policy.control_plane.health_path } else { "/health" }
  $syncPath   = if ($Policy.control_plane.sync_path)   { [string]$Policy.control_plane.sync_path }   else { "/sync" }
  $timeout    = if ($Policy.control_plane.timeout_sec) { [int]$Policy.control_plane.timeout_sec } else { 3 }

  try {
    $h = Invoke-RestMethod -Method Get -Uri ($base.TrimEnd("/") + $healthPath) -TimeoutSec $timeout
    Write-GFLog -Path $GFLogEvidence -Level "INFO" -Message "[API] health ok: $($h | ConvertTo-Json -Compress)"

    $s = Invoke-RestMethod -Method Post -Uri ($base.TrimEnd("/") + $syncPath) -TimeoutSec $timeout
    Write-GFLog -Path $GFLogEvidence -Level "INFO" -Message "[API] sync ok: $($s | ConvertTo-Json -Compress)"
    return $true
  } catch {
    Write-GFLog -Path $GFLogGuardian -Level "WARN" -Message ("[API] enforce failed: " + $_.Exception.Message)
    return $false
  }
}

function Invoke-GFEnforcePolicy_PowerShell {
  param([object] $Policy)

  try {
    # ---- Replace filenames with your real enforcers (these are safe defaults) ----
    $scripts = @(
      "C:\ProgramData\GuardianFW\engine\doh-enforcement.ps1",
      "C:\ProgramData\GuardianFW\engine\wfp-apply.ps1"
    )

    foreach ($s in $scripts) {
      if (Test-Path $s) {
        & $s
        if ($LASTEXITCODE -ne 0) {
          Write-GFLog -Path $GFLogGuardian -Level "WARN" -Message "[PS] $([IO.Path]::GetFileName($s)) failed exit=$LASTEXITCODE"
          return $false
        } else {
          Write-GFLog -Path $GFLogEvidence -Level "INFO" -Message "[PS] $([IO.Path]::GetFileName($s)) ok"
        }
      } else {
        Write-GFLog -Path $GFLogGuardian -Level "WARN" -Message "[PS] required script missing: $s"
      return $false
      }
    }

    if ($Policy.network -and $Policy.network.block_quic -eq $true) {
      Write-GFLog -Path $GFLogEvidence -Level "INFO" -Message "[PS] policy.network.block_quic=true (ensure enforced)"
    }

    return $true
  } catch {
    Write-GFLog -Path $GFLogGuardian -Level "ERR" -Message ("[PS] enforce fatal: " + $_.Exception.Message)
    return $false
  }
}

