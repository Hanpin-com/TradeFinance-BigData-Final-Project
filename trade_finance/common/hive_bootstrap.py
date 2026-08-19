import os, time
from pathlib import Path
from pyhive import hive
from trade_finance.common.config import HIVE_HOST, HIVE_PORT


def apply_hive_schema():
    if os.getenv("AUTO_CREATE_HIVE_SCHEMA", "true").lower() != "true":
        return

    path = Path(
        os.getenv(
            "HIVE_SCHEMA_FILE",
            "/app/sql/TradeFinance/01-hive-schema.sql"
        )
    )

    if not path.exists():
        print(f"Hive schema file not found: {path}", flush=True)
        return

    sql = path.read_text(encoding="utf-8")
    statements = [x.strip() for x in sql.split(";") if x.strip()]

    last = None

    for attempt in range(30):
        try:
            conn = hive.Connection(
                host=HIVE_HOST,
                port=HIVE_PORT,
                database="default",
                username="root"
            )

            cur = conn.cursor()

            for stmt in statements:
                cur.execute(stmt)

            cur.close()
            conn.close()

            print("Trade Finance Hive schema applied.", flush=True)
            return

        except Exception as exc:
            last = exc
            print(
                f"Hive schema attempt {attempt + 1}/30 failed: {exc}",
                flush=True
            )
            time.sleep(10)

    print(
        f"WARNING: Hive schema was not applied automatically: {last}",
        flush=True
    )