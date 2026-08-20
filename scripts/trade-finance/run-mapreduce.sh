#!/usr/bin/env bash
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
INPUT_JSON="$REPO_ROOT/data/trade-finance/transactions.json"
HDFS_BASE="/trade-finance/member2"
HDFS_INPUT="$HDFS_BASE/input/transactions.jsonl"
HDFS_OUTPUT="$HDFS_BASE/output/by_product_country_currency"

if [[ ! -f "$INPUT_JSON" ]]; then
  echo "Missing input file: $INPUT_JSON" >&2
  echo "Run the Trade Finance data generator first." >&2
  exit 1
fi

if ! docker ps --format '{{.Names}}' | grep -qx namenode; then
  echo "The namenode container is not running." >&2
  echo "Start the Hadoop services before running this script." >&2
  exit 1
fi

echo "Copying the Member 2 job into the namenode container..."
docker cp "$INPUT_JSON" namenode:/tmp/tf-transactions.json
docker cp "$REPO_ROOT/mapreduce/prepare_transactions.py" namenode:/tmp/prepare_transactions.py
docker cp "$REPO_ROOT/mapreduce/mapper.py" namenode:/tmp/mapper.py
docker cp "$REPO_ROOT/mapreduce/reducer.py" namenode:/tmp/reducer.py

docker exec namenode python3 \
  /tmp/prepare_transactions.py \
  /tmp/tf-transactions.json \
  /tmp/tf-transactions.jsonl

echo "Loading JSON Lines into HDFS..."
docker exec namenode hdfs dfs -mkdir -p "$HDFS_BASE/input"
docker exec namenode hdfs dfs -rm -f "$HDFS_INPUT"
docker exec namenode hdfs dfs -put /tmp/tf-transactions.jsonl "$HDFS_INPUT"
docker exec namenode hdfs dfs -rm -r -f "$HDFS_OUTPUT"

echo "Running Hadoop Streaming aggregation..."
docker exec namenode bash -lc '
  set -euo pipefail
  STREAMING_JAR=$(find /opt/hadoop/share/hadoop/tools/lib \
    -name "hadoop-streaming-*.jar" | head -n 1)
  test -n "$STREAMING_JAR"
  hadoop jar "$STREAMING_JAR" \
    -D mapreduce.job.name="Member2 Trade Finance Aggregation" \
    -D mapreduce.job.reduces=1 \
    -files /tmp/mapper.py,/tmp/reducer.py \
    -mapper "python3 mapper.py" \
    -reducer "python3 reducer.py" \
    -input /trade-finance/member2/input/transactions.jsonl \
    -output /trade-finance/member2/output/by_product_country_currency
'

echo
echo "product_type  beneficiary_country  currency  transaction_count  total_value"
docker exec namenode hdfs dfs -cat "$HDFS_OUTPUT/part-*"
