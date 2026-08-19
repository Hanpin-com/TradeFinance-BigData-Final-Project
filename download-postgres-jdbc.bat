@echo off
setlocal
cd /d %~dp0
if not exist downloads mkdir downloads
powershell -ExecutionPolicy Bypass -Command "Invoke-WebRequest -Uri 'https://jdbc.postgresql.org/download/postgresql-42.7.4.jar' -OutFile 'downloads/postgresql-42.7.4.jar'"
