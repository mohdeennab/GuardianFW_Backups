function Invoke-WithTimeout {
  param(
    [Parameter(Mandatory=$true)][scriptblock]$ScriptBlock,
    [int]$TimeoutSec = 10
  )

  $job = Start-Job -ScriptBlock $ScriptBlock
  try {
    $done = Wait-Job -Job $job -Timeout $TimeoutSec
    if(-not $done){
      Stop-Job $job -Force -ErrorAction SilentlyContinue | Out-Null
      Remove-Job $job -Force -ErrorAction SilentlyContinue | Out-Null
      throw "TIMEOUT after ${TimeoutSec}s"
    }
    $out = Receive-Job $job -Keep
    Remove-Job $job -Force -ErrorAction SilentlyContinue | Out-Null
    return $out
  } catch {
    try { Stop-Job $job -Force -ErrorAction SilentlyContinue | Out-Null } catch {}
    try { Remove-Job $job -Force -ErrorAction SilentlyContinue | Out-Null } catch {}
    throw
  }
}
