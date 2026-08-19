#!/usr/bin/env bash
set -euo pipefail

LOOKUP_TRANSACTION_ID="${1:-TF-DEMO-MEMBER2-0001}"

if [[ ! "$LOOKUP_TRANSACTION_ID" =~ ^[A-Za-z0-9._-]+$ ]]; then
  echo "Transaction ID contains unsupported characters." >&2
  exit 1
fi

if ! docker ps --format '{{.Names}}' | grep -qx hbase; then
  echo "The hbase container is not running." >&2
  echo "Start HBase before running this script." >&2
  exit 1
fi

echo "Running HBase PUT, GET, and SCAN operations..."
docker exec -i hbase hbase shell -n <<EOF
put 'trade_transactions', 'TF-DEMO-MEMBER2-0001', 'instrument:product_type', 'IMPORT_LC'
put 'trade_transactions', 'TF-DEMO-MEMBER2-0001', 'instrument:status', 'ACTIVE'
put 'trade_transactions', 'TF-DEMO-MEMBER2-0001', 'parties:applicant_id', 'CUST-DEMO-0001'
put 'trade_transactions', 'TF-DEMO-MEMBER2-0001', 'parties:beneficiary_id', 'CP-DEMO-0001'
put 'trade_transactions', 'TF-DEMO-MEMBER2-0001', 'geography:applicant_country', 'CA'
put 'trade_transactions', 'TF-DEMO-MEMBER2-0001', 'geography:beneficiary_country', 'US'
put 'trade_transactions', 'TF-DEMO-MEMBER2-0001', 'financial:currency', 'CAD'
put 'trade_transactions', 'TF-DEMO-MEMBER2-0001', 'financial:amount', '125000.00'
put 'trade_transactions', 'TF-DEMO-MEMBER2-0001', 'risk:customer_risk_rating', 'LOW'
put 'trade_transactions', 'TF-DEMO-MEMBER2-0001', 'audit:created_by', 'member2-hive-hbase'

get 'trade_transactions', '${LOOKUP_TRANSACTION_ID}'

scan 'trade_transactions', {FILTER => "PrefixFilter('TF-')", LIMIT => 5}

scan 'trade_events', {FILTER => "PrefixFilter('${LOOKUP_TRANSACTION_ID}#')", LIMIT => 10}
EOF

echo "HBase operations completed."
