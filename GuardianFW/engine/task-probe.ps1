$ErrorActionPreference="SilentlyContinue"
$probePath = "$env:WINDIR\Temp\GFW_TASK_PROBE_PS.txt"
"{0} | USER={1}\{2} | PID={3}" -f (Get-Date -Format s), $env:USERDOMAIN, $env:USERNAME, $PID |
  Add-Content -LiteralPath $probePath -Encoding UTF8
