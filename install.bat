@echo off
rem Windows: double-click to install work-diary. Pass -Uninstall to remove.
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0install.ps1" %*
echo.
pause
