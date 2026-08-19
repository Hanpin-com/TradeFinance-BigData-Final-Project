#!/usr/bin/env bash
set -e
/opt/bigdata/bin/wait-for.sh namenode 9870 namenode-web
/opt/bigdata/bin/wait-for.sh resourcemanager 8088 yarn-web
/opt/bigdata/bin/wait-for.sh spark-master 8080 spark-web
/opt/bigdata/bin/wait-for.sh hive-server 10000 hive-server2
/opt/bigdata/bin/wait-for.sh hbase 16010 hbase-web
hdfs dfs -mkdir -p /validation
hdfs dfs -put -f /etc/hosts /validation/hosts.txt
hdfs dfs -test -e /validation/hosts.txt
spark-submit --master spark://spark-master:7077 --class org.apache.spark.examples.SparkPi /opt/spark/examples/jars/spark-examples_2.12-3.5.0.jar 2 || true
beeline -u jdbc:hive2://hive-server:10000 -n root -e 'CREATE DATABASE IF NOT EXISTS validation; SHOW DATABASES;' || true
pig -x mapreduce -e 'fs -ls /;' || true
sqoop version || true
echo "Stack validation finished. Review optional warnings above for Hive/Pig/Sqoop client compatibility."
