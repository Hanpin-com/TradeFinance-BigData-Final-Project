@echo off
setlocal
cd /d %~dp0
set MISSING=0
for %%F in (hadoop-3.5.0.tar.gz spark-3.5.0-bin-hadoop3.tgz apache-hive-3.1.3-bin.tar.gz pig-0.17.0.tar.gz sqoop-1.4.7.bin__hadoop-2.6.0.tar.gz hbase-2.5.11-bin.tar.gz postgresql-42.7.4.jar) do (
  if not exist downloads\%%F (
    echo Missing downloads\%%F
    set MISSING=1
  )
)
if "%MISSING%"=="1" exit /b 1
echo All required local archives exist.
