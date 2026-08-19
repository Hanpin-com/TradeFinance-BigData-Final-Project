#!/usr/bin/env bash
set -e
ROLE="${SPARK_ROLE:-}"
/opt/bigdata/bin/wait-for.sh namenode 9000 namenode-rpc
if [ "$ROLE" = "master" ]; then
  hdfs dfs -mkdir -p /spark-events || true
  hdfs dfs -chmod 777 /spark-events || true
  /opt/spark/sbin/start-master.sh -h spark-master -p 7077 --webui-port 8080
  tail -f /opt/spark/logs/*
elif [ "$ROLE" = "worker" ]; then
  /opt/bigdata/bin/wait-for.sh spark-master 7077 spark-master
  /opt/spark/sbin/start-worker.sh spark://spark-master:7077 --webui-port 8081
  tail -f /opt/spark/logs/*
elif [ "$ROLE" = "history" ]; then
  hdfs dfs -mkdir -p /spark-events || true
  hdfs dfs -chmod 777 /spark-events || true
  /opt/spark/sbin/start-history-server.sh
  tail -f /opt/spark/logs/*
else
  echo "Unknown SPARK_ROLE: $ROLE" >&2
  exit 1
fi
