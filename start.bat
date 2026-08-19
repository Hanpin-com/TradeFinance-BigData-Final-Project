@echo off
setlocal
cd /d %~dp0
call build-base.bat
if errorlevel 1 exit /b 1
docker compose build --no-cache
if errorlevel 1 exit /b 1
docker compose up -d
