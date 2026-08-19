import time, happybase
from trade_finance.common.config import HBASE_HOST, HBASE_PORT

SCHEMA = {
    "trade_transactions": ["instrument","parties","geography","trade","financial","status","risk","ml","audit","metrics"],
    "trade_events": ["event","workflow","source","audit"],
    "trade_documents": ["document","presentation","examination","discrepancy","audit"],
    "trade_counterparties": ["profile","relationship","activity","risk","audit"],
    "trade_ml_results": ["prediction","model","features","evaluation","audit"],
    "trade_fx_rates": ["rate","source","audit"],
}

def connect(retries=60):
    last = None
    for _ in range(retries):
        try:
            conn = happybase.Connection(HBASE_HOST, HBASE_PORT, timeout=30000)
            conn.open()
            conn.tables()
            return conn
        except Exception as exc:
            last = exc
            print(f"Waiting for HBase Thrift {HBASE_HOST}:{HBASE_PORT}: {exc}", flush=True)
            time.sleep(5)
    raise RuntimeError(f"HBase unavailable: {last}")

def ensure_schema(conn):
    existing = {t.decode() if isinstance(t, bytes) else t for t in conn.tables()}
    for table, families in SCHEMA.items():
        if table not in existing:
            conn.create_table(table, {f: dict(max_versions=3) for f in families})
            print(f"Created HBase table {table}", flush=True)
