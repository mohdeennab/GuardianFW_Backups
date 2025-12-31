param(
  [string]$Control = "http://127.0.0.1:5052",
  [string]$AgentLog = "C:\GuardianFW\GuardianSuite\agent\agent.log",
  [string]$Db = "C:\GuardianFW\GuardianSuite\data\guardian.db"
)

"=== Services ==="
Get-Service GuardianControl,GuardianAgent -ErrorAction SilentlyContinue | Format-Table -AutoSize

""
"=== Control health ==="
try {
  curl.exe -s "$Control/health"
} catch {
  "Control not reachable: $Control"
}

""
"=== 5052 listener ==="
netstat -ano | Select-String "LISTENING" | Select-String ":5052" | ForEach-Object { $_.Line }

""
"=== Agent process ==="
Get-CimInstance Win32_Process |
  Where-Object { $_.CommandLine -match "guardian_agent\.py" } |
  Select-Object ProcessId,Name,CommandLine |
  Format-Table -AutoSize

""
"=== Agent last lines ==="
if(Test-Path $AgentLog){
  Get-Content $AgentLog -Tail 20
} else {
  "agent.log not found: $AgentLog"
}

""
"=== state.json ==="
$state = "C:\GuardianFW\GuardianSuite\agent\state.json"
if(Test-Path $state){
  Get-Content $state -Raw
} else {
  "state.json missing"
}

""
"=== Latest devices (DB) ==="
if(Test-Path $Db){
  $py = Join-Path $env:TEMP "guardian_seen.py"
  @"
import sqlite3, datetime
db=r"$Db"
con=sqlite3.connect(db); cur=con.cursor()
cur.execute("select device_id,name,profile,last_seen from devices order by last_seen desc limit 10;")
rows=cur.fetchall()
for d,n,p,ls in rows:
    ts=datetime.datetime.fromtimestamp(ls).strftime("%Y-%m-%d %H:%M:%S") if ls else ""
    print(f"{d}\t{n}\t{p}\t{ts}")
con.close()
"@ | Set-Content $py -Encoding UTF8
  python $py
} else {
  "DB not found: $Db"
}
