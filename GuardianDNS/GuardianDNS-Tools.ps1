function Set-GuardianDNSProfile {
  param([Parameter(Mandatory)][ValidateSet("Kids","Adults")] [string]$Profile)
  $Base="C:\GuardianFW\GuardianDNS"
  [System.IO.File]::WriteAllText("$Base\active-profile.txt",$Profile,(New-Object System.Text.UTF8Encoding($false)))
  "Active profile set to: $Profile"
}

function Add-GuardianDNSTemporaryAllow {
  param(
    [Parameter(Mandatory)][string]$Domain,
    [Parameter(Mandatory)][int]$Minutes,
    [string]$Reason = ""
  )
  $Base="C:\GuardianFW\GuardianDNS"
  $path="$Base\timed-allow.json"

  if(!(Test-Path $path)){
    $init = @{ version=1; items=@() } | ConvertTo-Json -Depth 10
    [System.IO.File]::WriteAllText($path,$init,(New-Object System.Text.UTF8Encoding($false)))
  }

  $obj = Get-Content $path -Raw | ConvertFrom-Json
  if($null -eq $obj.items){ $obj.items = @() }

  $expires = (Get-Date).ToUniversalTime().AddMinutes($Minutes).ToString("o")

  # replace same-domain
  $obj.items = @($obj.items | Where-Object { $_.domain -ne $Domain })
  $obj.items += [pscustomobject]@{ domain=$Domain; expires_at=$expires; reason=$Reason }

  $json = $obj | ConvertTo-Json -Depth 10
  [System.IO.File]::WriteAllText($path,$json,(New-Object System.Text.UTF8Encoding($false)))

  "Temporary allow added: $Domain for $Minutes minutes (expires $expires UTC)"
}

function Remove-GuardianDNSTemporaryAllow {
  param([Parameter(Mandatory)][string]$Domain)
  $Base="C:\GuardianFW\GuardianDNS"
  $path="$Base\timed-allow.json"
  if(!(Test-Path $path)){ "No timed-allow.json"; return }

  $obj = Get-Content $path -Raw | ConvertFrom-Json
  if($null -eq $obj.items){ $obj.items = @() }

  $before = @($obj.items).Count
  $obj.items = @($obj.items | Where-Object { $_.domain -ne $Domain })
  $after  = @($obj.items).Count

  $json = $obj | ConvertTo-Json -Depth 10
  [System.IO.File]::WriteAllText($path,$json,(New-Object System.Text.UTF8Encoding($false)))
  "Removed: $Domain (items: $before -> $after)"
}

function Clear-GuardianDNSTemporaryAllowExpired {
  $Base="C:\GuardianFW\GuardianDNS"
  $path="$Base\timed-allow.json"
  if(!(Test-Path $path)){ "No timed-allow.json"; return }

  $obj = Get-Content $path -Raw | ConvertFrom-Json
  if($null -eq $obj.items){ $obj.items = @() }

  $now = (Get-Date).ToUniversalTime()
  $before = @($obj.items).Count

  $obj.items = @($obj.items | Where-Object {
    ([datetime]::Parse($_.expires_at).ToUniversalTime()) -gt $now
  })

  $after = @($obj.items).Count
  $json = $obj | ConvertTo-Json -Depth 10
  [System.IO.File]::WriteAllText($path,$json,(New-Object System.Text.UTF8Encoding($false)))

  "Expired cleaned: $before -> $after"
}

function Get-GuardianDNSTemporaryAllows {
  $Base="C:\GuardianFW\GuardianDNS"
  $path="$Base\timed-allow.json"
  if(!(Test-Path $path)){ "No timed-allow.json"; return }

  $obj = Get-Content $path -Raw | ConvertFrom-Json
  if($null -eq $obj.items){ $obj.items = @() }

  $now = (Get-Date).ToUniversalTime()

  $items = @($obj.items) | ForEach-Object {
    $exp = [datetime]::Parse($_.expires_at).ToUniversalTime()
    [pscustomobject]@{
      Domain      = $_.domain
      ExpiresUTC  = $exp
      MinutesLeft = [math]::Max(0,[int](($exp-$now).TotalMinutes))
      Reason      = $_.reason
      Active      = ($exp -gt $now)
    }
  }

  $items | Sort-Object -Property Active, ExpiresUTC -Descending
}
