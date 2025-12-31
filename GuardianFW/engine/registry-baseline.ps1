$ErrorActionPreference="Stop"
$root="C:\ProgramData\GuardianFW"
$intDir="$root\integrity"
$evDir="$root\evidence\registry"
New-Item -ItemType Directory -Path $intDir -Force | Out-Null
New-Item -ItemType Directory -Path $evDir  -Force | Out-Null

$targets = @(
  @{ name="DNSClientPolicy"; path="HKLM:\SOFTWARE\Policies\Microsoft\Windows NT\DNSClient"; patterns=@("*DNS*","*DoH*","*DnsOverHttps*","*SecureDns*") },
  @{ name="ChromePolicy";    path="HKLM:\SOFTWARE\Policies\Google\Chrome";               patterns=@("*DoH*","*DnsOverHttps*","*SecureDns*","*Quic*") },
  @{ name="EdgePolicy";      path="HKLM:\SOFTWARE\Policies\Microsoft\Edge";             patterns=@("*DoH*","*DnsOverHttps*","*SecureDns*","*Quic*") },
  @{ name="FirefoxPolicy";   path="HKLM:\SOFTWARE\Policies\Mozilla\Firefox";            patterns=@("*DoH*","*DnsOverHttps*","*SecureDns*","*Quic*") }
)

function Get-KeySnapshot($p, $patterns) {
  if (!(Test-Path $p)) { return $null }
  $item = Get-ItemProperty -Path $p -ErrorAction Stop

  $props = @{}
  foreach ($pr in $item.PSObject.Properties) {
    if ($pr.Name -in @("PSPath","PSParentPath","PSChildName","PSDrive","PSProvider")) { continue }
    foreach ($pat in $patterns) {
      if ($pr.Name -like $pat) { $props[$pr.Name] = $pr.Value; break }
    }
  }

  return @{
    path   = $p
    values = $props
  }
}

$snap = @()
foreach ($t in $targets) {
  $s = Get-KeySnapshot $t.path $t.patterns
  if ($null -ne $s) {
    $snap += @{
      name = $t.name
      path = $t.path
      values = $s.values
    }
  }
}

$baseline = @{
  timestamp = (Get-Date).ToString("s")
  mode      = "guardian-only"
  keys      = $snap
}

$baseline | ConvertTo-Json -Depth 10 | Out-File "$intDir\registry-baseline.json" -Encoding UTF8
$baseline | ConvertTo-Json -Depth 10 | Out-File "$evDir\baseline-$(Get-Date -Format yyyyMMdd-HHmmss).json" -Encoding UTF8
