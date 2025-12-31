Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$Root   = "C:\ProgramData\GuardianFW"
$Policy = Join-Path $Root "policy\policy.json"
$Sig    = Join-Path $Root "policy\policy.json.sig"
$PubKey = Join-Path $Root "keys\policy_pubkey.xml"
$Fail   = Join-Path $Root "sealed\FAIL_SECURE.flag"

function Ensure-EventSource {
  if (-not [System.Diagnostics.EventLog]::SourceExists("GuardianFW")) {
    New-EventLog -LogName Application -Source "GuardianFW"
  }
}

function Enter-FailSecure([string]$Reason) {
  if (!(Test-Path $Fail)) { New-Item -ItemType File -Path $Fail -Force | Out-Null }
  Ensure-EventSource
  Write-EventLog -LogName Application -Source "GuardianFW" -EventId 9001 -EntryType Error -Message "GuardianFW FAIL-SECURE: $Reason"
  throw "FAIL-SECURE: $Reason"
}

if (!(Test-Path $Policy)) { Enter-FailSecure "policy.json missing" }
if (!(Test-Path $Sig))    { Enter-FailSecure "policy signature missing" }
if (!(Test-Path $PubKey)) { Enter-FailSecure "policy public key missing" }

$rsa = [System.Security.Cryptography.RSA]::Create()
$rsa.FromXmlString((Get-Content $PubKey -Raw -Encoding UTF8))

$policyBytes = [Text.Encoding]::UTF8.GetBytes((Get-Content $Policy -Raw -Encoding UTF8))
$sigText = (Get-Content $Sig -Raw -Encoding UTF8).Trim()
$sigBytes = [Convert]::FromBase64String($sigText)

$valid = $rsa.VerifyData($policyBytes, $sigBytes,
  [System.Security.Cryptography.HashAlgorithmName]::SHA256,
  [System.Security.Cryptography.RSASignaturePadding]::Pkcs1
)

if (-not $valid) { Enter-FailSecure "policy signature INVALID" }

if (Test-Path $Fail) { Remove-Item -LiteralPath $Fail -Force -EA SilentlyContinue }

Ensure-EventSource
Write-EventLog -LogName Application -Source "GuardianFW" -EventId 9000 -EntryType Information -Message "GuardianFW policy verified successfully"
