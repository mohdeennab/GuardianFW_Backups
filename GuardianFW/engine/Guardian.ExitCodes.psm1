# Guardian.ExitCodes.psm1
Set-StrictMode -Version Latest

# Canonical exit codes
$script:EXIT_OK      = 0
$script:EXIT_NOOP    = 10
$script:EXIT_DRIFT   = 20
$script:EXIT_FAIL    = 30
$script:EXIT_INVALID = 40
$script:EXIT_TAMPER  = 50

function Get-GfwExitCode {
  param([ValidateSet("OK","NOOP","DRIFT","FAIL","INVALID","TAMPER")] [string]$Name)
  switch($Name){
    "OK"      { $script:EXIT_OK }
    "NOOP"    { $script:EXIT_NOOP }
    "DRIFT"   { $script:EXIT_DRIFT }
    "FAIL"    { $script:EXIT_FAIL }
    "INVALID" { $script:EXIT_INVALID }
    "TAMPER"  { $script:EXIT_TAMPER }
  }
}

Export-ModuleMember -Variable EXIT_OK,EXIT_NOOP,EXIT_DRIFT,EXIT_FAIL,EXIT_INVALID,EXIT_TAMPER -Function Get-GfwExitCode