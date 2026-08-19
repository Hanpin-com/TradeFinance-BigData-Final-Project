#!/usr/bin/env bash
set -euo pipefail
cat >/tmp/tf.hbase <<'EOF'
create 'trade_transactions','instrument','parties','geography','trade','financial','status','risk','ml','audit','metrics'
create 'trade_events','event','workflow','source','audit'
create 'trade_documents','document','presentation','examination','discrepancy','audit'
create 'trade_counterparties','profile','relationship','activity','risk','audit'
create 'trade_ml_results','prediction','model','features','evaluation','audit'
create 'trade_fx_rates','rate','source','audit'
list
EOF
hbase shell -n /tmp/tf.hbase
