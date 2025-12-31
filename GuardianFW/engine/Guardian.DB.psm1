# Guardian.DB.psm1
Set-StrictMode -Version Latest

function Get-GfwDbPath { "C:\ProgramData\GuardianFW\policy\guardian.db" }
function Get-GfwSqliteExe { "C:\ProgramData\GuardianFW\tools\sqlite3.exe" }

function Invoke-GfwSqlite {
  param([Parameter(Mandatory)][string]$Sql)

  $exe = Get-GfwSqliteExe
  $db  = Get-GfwDbPath

  if(-not (Test-Path $exe)){
    return @{"__GFW_SQLITE_MISSING__"=$true;"path"=$exe}
  }

  $policyDir = Split-Path -Parent $db
  if(-not (Test-Path $policyDir)){ New-Item -ItemType Directory -Path $policyDir -Force | Out-Null }

  $out = & $exe $db $Sql 2>&1
  return $out
}

function Initialize-GfwDb {
  # If sqlite3.exe is not bundled yet, skip DB init (Phase1 wrapper is allowed to run without DB).
  $probe = Invoke-GfwSqlite "SELECT 1;"
  if($probe -is [hashtable] -and $probe.ContainsKey("__GFW_SQLITE_MISSING__")){ return }

  $schema = @"
PRAGMA journal_mode=WAL;
PRAGMA synchronous=NORMAL;

CREATE TABLE IF NOT EXISTS policy(
  id TEXT PRIMARY KEY,
  version INTEGER,
  mode TEXT,
  hash TEXT,
  created_at TEXT
);

CREATE TABLE IF NOT EXISTS rules(
  id TEXT PRIMARY KEY,
  type TEXT,
  target TEXT,
  action TEXT,
  scope TEXT,
  enabled INTEGER
);

CREATE TABLE IF NOT EXISTS state(
  key TEXT PRIMARY KEY,
  value TEXT
);

CREATE TABLE IF NOT EXISTS evidence(
  event_id TEXT PRIMARY KEY,
  type TEXT,
  severity TEXT,
  timestamp TEXT,
  policy_id TEXT,
  result_code INTEGER
);
"@
  Invoke-GfwSqlite $schema | Out-Null
}

function Set-GfwState([string]$Key,[string]$Value){
  $sql = "INSERT INTO state(key,value) VALUES('$Key','$Value') ON CONFLICT(key) DO UPDATE SET value=excluded.value;"
  Invoke-GfwSqlite $sql | Out-Null
}

function Get-GfwState([string]$Key){
  $sql = "SELECT value FROM state WHERE key='$Key' LIMIT 1;"
  $r = Invoke-GfwSqlite $sql
  if($null -eq $r -or $r.Count -eq 0){ return $null }
  ($r | Select-Object -First 1).ToString().Trim()
}

Export-ModuleMember -Function Initialize-GfwDb,Invoke-GfwSqlite,Set-GfwState,Get-GfwState
