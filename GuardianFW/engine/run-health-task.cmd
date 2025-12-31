@echo off
setlocal enableextensions
mkdir "C:\ProgramData\GuardianFW\logs" 2>nul

echo ==== %DATE% %TIME% START (task) ====>> "C:\ProgramData\GuardianFW\logs\health-task.cmd.out"
whoami >> "C:\ProgramData\GuardianFW\logs\health-task.cmd.out" 2>&1
echo PWD=%CD%>> "C:\ProgramData\GuardianFW\logs\health-task.cmd.out"
echo PS=C:\Windows\System32\WindowsPowerShell\v1.0\powershell.exe>> "C:\ProgramData\GuardianFW\logs\health-task.cmd.out"
if exist "C:\Windows\System32\WindowsPowerShell\v1.0\powershell.exe" (echo PS_EXISTS=YES>> "C:\ProgramData\GuardianFW\logs\health-task.cmd.out") else (echo PS_EXISTS=NO>> "C:\ProgramData\GuardianFW\logs\health-task.cmd.out")
echo BEFORE_POWERSHELL>> "C:\ProgramData\GuardianFW\logs\health-task.cmd.out"

"%SystemRoot%\System32\WindowsPowerShell\v1.0\powershell.exe" -NoProfile -ExecutionPolicy Bypass -Command ^
  "& { try { & 'C:\ProgramData\GuardianFW\engine\run-health-phase1.ps1' } catch { '[[TASKTRACE_ERROR]] ' + $_ | Out-Host }; '[[TASKTRACE_LASTEXIT]] ' + $LASTEXITCODE | Out-Host; exit $LASTEXITCODE }" >> "C:\ProgramData\GuardianFW\logs\health-task.cmd.out" 2>&1

echo AFTER_POWERSHELL>> "C:\ProgramData\GuardianFW\logs\health-task.cmd.out"
echo exitcode=%errorlevel%>> "C:\ProgramData\GuardianFW\logs\health-task.cmd.out"
echo ==== %DATE% %TIME% END (task) ====>> "C:\ProgramData\GuardianFW\logs\health-task.cmd.out"
exit /b %errorlevel%

