# Guardian.Map.psm1
Set-StrictMode -Version Latest

function Convert-GfwInnerExitToCanonical {
  param([int]$InnerExit)

  # Your inner script currently returns:
  # 0 = OK
  # 2 = (some non-fatal/other) -> treat as FAIL for now until we define exact meaning
  # You can refine this mapping later without changing enforcement behavior.

  switch($InnerExit){
    0 { return @{ result="OK"; exit_code=0 } }
    10 { return @{ result="NOOP"; exit_code=10 } }
    20 { return @{ result="DRIFT"; exit_code=20 } }
    30 { return @{ result="FAIL"; exit_code=30 } }
    40 { return @{ result="INVALID"; exit_code=40 } }
    50 { return @{ result="TAMPER"; exit_code=50 } }
    default { return @{ result="FAIL"; exit_code=30 } }
  }
}

Export-ModuleMember -Function Convert-GfwInnerExitToCanonical
