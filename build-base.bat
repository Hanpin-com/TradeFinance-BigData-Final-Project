@echo off
setlocal
cd /d %~dp0
docker build -t bigdata-hadoop-base:local -f docker/base/Dockerfile .
