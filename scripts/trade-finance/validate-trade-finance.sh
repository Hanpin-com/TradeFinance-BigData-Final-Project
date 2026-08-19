#!/usr/bin/env bash
set -euo pipefail
echo "Kafka topics:"
docker exec kafka /opt/kafka/bin/kafka-topics.sh --bootstrap-server localhost:9092 --list | grep '^tf\.'
echo "HBase tables:"
docker exec hbase hbase shell -n <<< "list"
echo "Hive database/views:"
docker exec hive-server beeline -u jdbc:hive2://localhost:10000/default -e "SHOW DATABASES; USE trade_finance; SHOW TABLES;"
echo "Trade Finance containers:"
docker ps --format '{{.Names}} {{.Status}}' | grep '^tf-'
