#!/usr/bin/env bash
set -e
cd "$(dirname "$0")"
for f in hadoop-3.5.0.tar.gz spark-3.5.0-bin-hadoop3.tgz apache-hive-3.1.3-bin.tar.gz pig-0.17.0.tar.gz sqoop-1.4.7.bin__hadoop-2.6.0.tar.gz hbase-2.5.11-bin.tar.gz postgresql-42.7.4.jar; do
  test -f "downloads/$f" || { echo "Missing downloads/$f"; exit 1; }
done
echo "All required local archives exist."
