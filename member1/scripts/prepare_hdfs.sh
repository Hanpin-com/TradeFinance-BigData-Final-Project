#!/usr/bin/env bash
# Member 1 – HDFS landing zone for Trade Finance historical data
set -euo pipefail

HDFS_BASE=${HDFS_BASE:-/user/tradefinance}
LOCAL_DIR=${1:-/data/member1}

echo "=== Create HDFS layout under ${HDFS_BASE} ==="
hdfs dfs -mkdir -p "${HDFS_BASE}/raw/transactions"
hdfs dfs -mkdir -p "${HDFS_BASE}/raw/customers"
hdfs dfs -mkdir -p "${HDFS_BASE}/raw/counterparties"
hdfs dfs -mkdir -p "${HDFS_BASE}/raw/events"
hdfs dfs -mkdir -p "${HDFS_BASE}/curated"
hdfs dfs -mkdir -p "${HDFS_BASE}/exports"

echo "=== Upload sample / available files ==="
if [[ -f "${LOCAL_DIR}/sample_transactions.csv" ]]; then
  hdfs dfs -put -f "${LOCAL_DIR}/sample_transactions.csv" "${HDFS_BASE}/raw/transactions/"
fi
# optional full-set paths if copied into container
for f in transactions.json customers.json counterparties.json events.jsonl; do
  if [[ -f "${LOCAL_DIR}/${f}" ]]; then
    case "$f" in
      transactions.json) dest=transactions ;;
      customers.json) dest=customers ;;
      counterparties.json) dest=counterparties ;;
      events.jsonl) dest=events ;;
    esac
    hdfs dfs -put -f "${LOCAL_DIR}/${f}" "${HDFS_BASE}/raw/${dest}/"
  fi
done

echo "=== Validate ==="
hdfs dfs -ls -R "${HDFS_BASE}"
hdfs dfs -du -h "${HDFS_BASE}"
hdfs dfs -cat "${HDFS_BASE}/raw/transactions/sample_transactions.csv" 2>/dev/null | head -5 || true
echo "Done."
