#!/usr/bin/env python3
"""Load generated Trade Finance transactions directly into HBase."""

import json
import os
from pathlib import Path

from trade_finance.common.hbase_schema import connect, ensure_schema


INPUT_PATH = Path(
    os.getenv(
        "TF_TRANSACTIONS_FILE",
        "/data/trade-finance/transactions.json",
    )
)

COLUMN_MAP = {
    b"instrument:product_type": "product_type",
    b"instrument:status": "status",
    b"instrument:issue_date": "issue_date",
    b"instrument:expiry_date": "expiry_date",
    b"parties:applicant_id": "applicant_id",
    b"parties:beneficiary_id": "beneficiary_id",
    b"geography:applicant_country": "applicant_country",
    b"geography:beneficiary_country": "beneficiary_country",
    b"trade:goods_category": "goods_category",
    b"financial:currency": "currency",
    b"financial:amount": "amount",
    b"metrics:amendment_count": "amendment_count",
    b"metrics:document_count": "document_count",
    b"metrics:processing_days": "processing_days",
    b"metrics:discrepancy_flag": "discrepancy_flag",
    b"metrics:delay_flag": "delay_flag",
    b"metrics:counterparty_relationship_years":
        "counterparty_relationship_years",
    b"risk:customer_risk_rating": "customer_risk_rating",
}


def encode(value: object) -> bytes:
    return str(value).encode("utf-8")


def main() -> None:
    if not INPUT_PATH.exists():
        raise FileNotFoundError(f"Transaction file not found: {INPUT_PATH}")

    with INPUT_PATH.open("r", encoding="utf-8") as source:
        transactions = json.load(source)

    if not isinstance(transactions, list):
        raise ValueError("Expected transactions.json to contain a JSON list")

    connection = connect()
    try:
        ensure_schema(connection)
        table = connection.table("trade_transactions")

        with table.batch(batch_size=500) as batch:
            for transaction in transactions:
                transaction_id = transaction.get("transaction_id")
                if not transaction_id:
                    raise ValueError("A transaction is missing transaction_id")

                row = {
                    column: encode(transaction[field])
                    for column, field in COLUMN_MAP.items()
                    if transaction.get(field) is not None
                }
                row[b"audit:load_source"] = b"member2_batch_loader"
                batch.put(encode(transaction_id), row)

        print(
            f"Loaded {len(transactions)} transactions into "
            "HBase table trade_transactions.",
            flush=True,
        )
    finally:
        connection.close()


if __name__ == "__main__":
    main()
