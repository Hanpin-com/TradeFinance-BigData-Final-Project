# Member 2 MapReduce Workload

This Hadoop Streaming job calculates transaction count and total transaction
value by:

- product type;
- beneficiary country; and
- currency.

Currency is included in the grouping key to prevent amounts such as CAD, USD,
EUR, GBP, JPY, and CNY from being added as if they had the same unit. CAD
conversion is handled separately in the Hive layer.

## Files

- `prepare_transactions.py` converts the generated JSON array to JSON Lines.
- `mapper.py` emits one count and amount for each transaction.
- `reducer.py` sums the count and amount for each aggregation key.
- `scripts/trade-finance/run-mapreduce.sh` runs the complete job in Docker.

## Run

Start the Hadoop services first, then run this command from the repository root:

```bash
bash scripts/trade-finance/run-mapreduce.sh
```

The result columns are:

```text
product_type  beneficiary_country  currency  transaction_count  total_value
```

The HDFS output directory is `/trade-finance/member2/output/by_product_country_currency`.
