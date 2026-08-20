#!/usr/bin/env bash
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
SCHEMA_FILE="$REPO_ROOT/sql/TradeFinance/01-hive-schema.sql"
ANALYTICS_FILE="$REPO_ROOT/sql/TradeFinance/02-member2-analytics.sql"

if ! docker ps --format '{{.Names}}' | grep -qx hive-server; then
  echo "The hive-server container is not running." >&2
  echo "Start Hive and HBase before running this script." >&2
  exit 1
fi

docker cp "$SCHEMA_FILE" hive-server:/tmp/01-hive-schema.sql
docker cp "$ANALYTICS_FILE" hive-server:/tmp/02-member2-analytics.sql

echo "Applying the Hive-to-HBase schema and analytical views..."
docker exec hive-server beeline \
  -u jdbc:hive2://localhost:10000/default \
  -f /tmp/01-hive-schema.sql

echo "Running Member 2 historical analytics..."
docker exec hive-server beeline \
  -u jdbc:hive2://localhost:10000/trade_finance \
  -f /tmp/02-member2-analytics.sql
