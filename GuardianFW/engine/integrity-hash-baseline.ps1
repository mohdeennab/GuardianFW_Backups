$ErrorActionPreference="Stop"
$root="C:\ProgramData\GuardianFW"
$intDir="$root\integrity"
$evDir="$root\evidence\integrity"
New-Item -ItemType Directory -Path $intDir -Force | Out-Null
New-Item -ItemType Directory -Path $evDir  -Force | Out-Null

# What GuardianFW "owns" and should not be silently changed
$paths = @(
  "$root\engine\*.ps1",
  "$root\policies\*.json",
  "$root\integrity\firewall-baseline.json",
  "$root\integrity\registry-baseline.json"
)

$files = Get-ChildItem -Path $paths -File -ErrorAction SilentlyContinue |
  Sort-Object FullName |
  ForEach-Object {
    $h = Get-FileHash -Algorithm SHA256 -Path $_.FullName
    @{
      path = $_.FullName
      sha256 = $h.Hash
      size = $_.Length
      mtime = $_.LastWriteTimeUtc.ToString("s")
    }
  }

$baseline = @{
  timestamp = (Get-Date).ToString("s")
  sha256    = $files
}

$baseline | ConvertTo-Json -Depth 6 | Out-File "$intDir\integrity-hashes.json" -Encoding UTF8
$baseline | ConvertTo-Json -Depth 6 | Out-File "$evDir\hash-baseline-$(Get-Date -Format yyyyMMdd-HHmmss).json" -Encoding UTF8
