@echo off
setlocal
cd /d %~dp0
docker compose --profile tools run --rm validator
