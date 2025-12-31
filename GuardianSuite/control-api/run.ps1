param(
  [int]$Port = 5050
)
$ErrorActionPreference = "Stop"
$here = Split-Path -Parent $MyInvocation.MyCommand.Path
Set-Location $here

if(!(Test-Path ".\.venv\Scripts\Activate.ps1")){
  throw "Missing venv. Run: python -m venv .venv"
}

& ".\.venv\Scripts\Activate.ps1"

$env:GUARDIAN_JWT_SECRET = "dev-only-change-me"
python -m uvicorn app.main:app --host 127.0.0.1 --port $Port
