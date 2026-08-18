@echo off
rem Double-click launcher for setup-signing.ps1
rem (this .bat just bypasses the execution policy for our own script)
cd /d "%~dp0.."
powershell -NoProfile -ExecutionPolicy Bypass -File "scripts\setup-signing.ps1"
echo.
pause
