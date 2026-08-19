#!/usr/bin/env bash
set -e
ROLE="${HADOOP_ROLE:-}"
case "$ROLE" in
  namenode)
    if [ ! -d /hadoop/dfs/name/current ]; then
      echo "Formatting HDFS NameNode..."
      hdfs namenode -format -force -nonInteractive
    fi
    exec hdfs namenode
    ;;
  datanode)
    /opt/bigdata/bin/wait-for.sh namenode 9000 namenode-rpc
    exec hdfs datanode
    ;;
  resourcemanager)
    /opt/bigdata/bin/wait-for.sh namenode 9000 namenode-rpc
    exec yarn resourcemanager
    ;;
  nodemanager)
    /opt/bigdata/bin/wait-for.sh resourcemanager 8032 resourcemanager
    exec yarn nodemanager
    ;;
  historyserver)
    /opt/bigdata/bin/wait-for.sh namenode 9000 namenode-rpc
    hdfs dfs -mkdir -p /tmp /user/history /spark-events /user/hive/warehouse || true
    hdfs dfs -chmod -R 1777 /tmp || true
    hdfs dfs -chmod -R 777 /spark-events /user/hive/warehouse || true
    exec mapred historyserver
    ;;
  *)
    echo "Unknown HADOOP_ROLE: $ROLE" >&2
    exit 1
    ;;
esac
