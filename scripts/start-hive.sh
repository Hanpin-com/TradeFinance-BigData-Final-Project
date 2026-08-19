#!/usr/bin/env bash
set -e

ROLE="${HIVE_ROLE:-}"

# ------------------------------------------------------------------
# Environment
# ------------------------------------------------------------------

export HIVE_HOME=/opt/hive
export HIVE_CONF_DIR=/opt/hive/conf

export HBASE_HOME=/opt/hbase
export HBASE_CONF_DIR=/opt/hbase/conf

export PATH="${HIVE_HOME}/bin:${HBASE_HOME}/bin:${PATH}"

# Make HBase client libraries available to Hive
export HIVE_AUX_JARS_PATH="/opt/hbase/lib"

if [ -n "${HADOOP_CLASSPATH:-}" ]; then
    export HADOOP_CLASSPATH="/opt/hbase/lib/*:${HADOOP_CLASSPATH}"
else
    export HADOOP_CLASSPATH="/opt/hbase/lib/*"
fi

echo "======================================================"
echo "Hive Startup"
echo "======================================================"
echo "ROLE                 : ${ROLE}"
echo "HIVE_HOME            : ${HIVE_HOME}"
echo "HBASE_HOME           : ${HBASE_HOME}"
echo "HIVE_AUX_JARS_PATH   : ${HIVE_AUX_JARS_PATH}"
echo "HADOOP_CLASSPATH     : ${HADOOP_CLASSPATH}"
echo "======================================================"

echo "Waiting for Hadoop NameNode..."
/opt/bigdata/bin/wait-for.sh namenode 9000 namenode-rpc

echo "Waiting for Hive Metastore PostgreSQL..."
/opt/bigdata/bin/wait-for.sh hive-metastore-postgresql 5432 postgres

echo "Preparing Hive directories in HDFS..."
hdfs dfs -mkdir -p /tmp /user/hive/warehouse || true
hdfs dfs -chmod 1777 /tmp || true
hdfs dfs -chmod -R 777 /user/hive/warehouse || true

if [ "${ROLE}" = "metastore" ]; then

    echo "Checking Hive Metastore schema..."

    if ! schematool -dbType postgres -info >/tmp/schema-info.log 2>&1; then
        echo "Initializing Hive Metastore schema..."
        schematool -dbType postgres -initSchema
    fi

    echo "Starting Hive Metastore..."
    exec hive --service metastore

elif [ "${ROLE}" = "server2" ]; then

    echo "Waiting for Hive Metastore..."
    /opt/bigdata/bin/wait-for.sh hive-metastore 9083 hive-metastore

    echo "Verifying HBase installation..."

    test -d /opt/hbase
    test -d /opt/hbase/lib
    test -f /opt/hive/lib/hive-hbase-handler-4.1.0.jar

    echo "HBase client libraries:"
    ls -1 /opt/hbase/lib | grep "^hbase-" || true

    echo "Starting HiveServer2..."
    exec /opt/hive/bin/hiveserver2

else

    echo "ERROR: Unknown HIVE_ROLE: ${ROLE}" >&2
    echo "Supported roles: metastore, server2" >&2
    exit 1

fi