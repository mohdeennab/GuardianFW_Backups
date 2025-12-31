@echo off
set ROOT=C:\ProgramData\GuardianFW
set PS=%WINDIR%\System32\WindowsPowerShell\v1.0\powershell.exe
"%PS%" -NoProfile -ExecutionPolicy Bypass -File "%ROOT%\engine\health.ps1" >> "%ROOT%\logs\health-task.out" 2>&1
exit /b %errorlevel%
