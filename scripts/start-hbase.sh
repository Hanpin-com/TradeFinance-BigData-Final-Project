#!/usr/bin/env bash
set -e

# ============================================================
# HBase Runtime
# ============================================================

export HBASE_PID_DIR=/tmp/hbase-pids

# Remove stale daemon PID files left by a previous container run.
# Docker container recreation/restart can otherwise make HBase
# believe that an old Master, RegionServer, or Thrift process
# is still running.
rm -rf "${HBASE_PID_DIR}"
mkdir -p "${HBASE_PID_DIR}"

echo "Waiting for Hadoop NameNode..."
/opt/bigdata/bin/wait-for.sh namenode 9000 namenode-rpc

echo "Waiting for ZooKeeper..."
/opt/bigdata/bin/wait-for.sh zookeeper 2181 zookeeper

echo "Preparing HBase root directory in HDFS..."
hdfs dfs -mkdir -p /hbase || true
hdfs dfs -chmod 777 /hbase || true

echo "Starting HBase Master..."
/opt/hbase/bin/hbase-daemon.sh start master

echo "Starting HBase RegionServer..."
/opt/hbase/bin/hbase-daemon.sh start regionserver

echo "Waiting for HBase Master..."
sleep 15

echo "Starting HBase Thrift Server..."
/opt/hbase/bin/hbase-daemon.sh start thrift

echo "HBase services started."

echo "Running Java processes:"
jps || true

echo "Keeping HBase container alive..."
tail -F /opt/hbase/logs/*