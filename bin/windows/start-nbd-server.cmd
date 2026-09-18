@echo off
setlocal
if "%~1"=="" (
  echo Usage: %~nx0 "C:\path\image.iso" [port]
  exit /b 2
)
set "ISO=%~1"
set "PORT=%~2"
if "%PORT%"=="" set "PORT=10810"
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0nbd-server.ps1" -Image "%ISO%" -Port %PORT%
endlocal
