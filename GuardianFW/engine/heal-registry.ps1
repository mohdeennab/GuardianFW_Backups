$ErrorActionPreference="Stop"
$root="C:\ProgramData\GuardianFW"
$polPath="$root\policies\registry-policy.json"
$evDir="$root\evidence\registry"
New-Item -ItemType Directory -Path $evDir -Force | Out-Null

if (!(Test-Path $polPath)) { throw "Missing: $polPath" }
$pol = Get-Content $polPath -Raw | ConvertFrom-Json

$changes=@()

foreach($t in $pol.targets){
  # In enterprise policy world, it's acceptable to create the policy key we own
  if(!(Test-Path $t.path)){
    New-Item -Path $t.path -Force | Out-Null
  }

  foreach($v in $t.values){
    $ptype = $v.type
    if($ptype -eq "DWord"){
      New-ItemProperty -Path $t.path -Name $v.name -Value ([int]$v.value) -PropertyType DWord -Force | Out-Null
    } else {
      New-ItemProperty -Path $t.path -Name $v.name -Value ([string]$v.value) -PropertyType String -Force | Out-Null
    }
    $changes += @{ key=$t.path; value=$v.name; setTo=$v.value; type=$ptype }
  }
}

$result=@{
  timestamp=(Get-Date).ToString("s")
  action="heal"
  changed=$changes
}

$result | ConvertTo-Json -Depth 10 | Out-File "$evDir\heal-$(Get-Date -Format yyyyMMdd-HHmmss).json" -Encoding UTF8
$result
