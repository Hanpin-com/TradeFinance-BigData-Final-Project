# Member 2: MapReduce, Hive, and HBase

This section implements the batch-processing and historical analytical layer of
the Trade Finance project. It uses the same generated transactions and HBase
tables as the rest of the team project.

## 1. MapReduce workload

The Hadoop Streaming job aggregates transaction count and transaction value by
product type, beneficiary country, and currency. Currency is part of the key so
different monetary units are not mixed.

Run from the repository root after Hadoop is running:

```bash
bash scripts/trade-finance/run-mapreduce.sh
```

The script performs the complete workflow:

1. Converts `transactions.json` to JSON Lines.
2. Copies the data into HDFS.
3. Runs the mapper and reducer through YARN.
4. Stores the result in
   `/trade-finance/member2/output/by_product_country_currency`.
5. Prints the final aggregation.

Output columns are product type, beneficiary country, currency, transaction
count, and total value.

## 2. Hive warehouse and analytics

`sql/TradeFinance/01-hive-schema.sql` maps the `trade_transactions` HBase table
to Hive using `HBaseStorageHandler`. The row key becomes `transaction_id`, while
the HBase column families become typed Hive columns.

The file creates these analytical views:

| View | Purpose |
| --- | --- |
| `tf_transactions_valued` | Row-level transactions with CAD valuation |
| `tf_trade_portfolio` | Product, status, and corridor portfolio summary |
| `tf_product_performance` | Product count, value, processing, and risk rates |
| `tf_country_exposure` | Beneficiary-country exposure |
| `tf_corridor_performance` | Applicant-to-beneficiary trade corridors |
| `tf_documentary_operations` | Documents, amendments, discrepancies, and processing |
| `tf_sla_performance` | Transactions within and outside a 10-day SLA |
| `tf_risk_summary` | Exposure by country, product, and customer risk rating |
| `tf_annual_growth` | Historical count and value by issue year and product |

Run the schema and the seven business queries with:

```bash
bash scripts/trade-finance/run-hive-analytics.sh
```

### CAD valuation methodology

The generated dataset contains CAD, USD, EUR, GBP, JPY, and CNY amounts. The
analysis uses fixed synthetic rates so results are deterministic and can be
compared in one reporting currency.

| Currency | CAD per unit |
| --- | ---: |
| CAD | 1.0000 |
| USD | 1.3600 |
| EUR | 1.4800 |
| GBP | 1.7300 |
| JPY | 0.0092 |
| CNY | 0.1900 |

These values are classroom assumptions, not live market rates. The conversion
is `amount_cad = amount_original * exchange_rate_to_cad`.

## 3. HBase data model

The existing application schema separates related attributes into column
families instead of storing one wide record.

| Table | Main purpose | Important column families |
| --- | --- | --- |
| `trade_transactions` | Current transaction state | `instrument`, `parties`, `geography`, `financial`, `risk`, `metrics`, `audit` |
| `trade_events` | Full event history | `event`, `workflow`, `source`, `audit` |
| `trade_documents` | Documentary workflow | `document`, `presentation`, `examination`, `discrepancy`, `audit` |
| `trade_counterparties` | Counterparty profile and risk | `profile`, `relationship`, `activity`, `risk`, `audit` |
| `trade_ml_results` | Model predictions | `prediction`, `model`, `features`, `evaluation`, `audit` |
| `trade_fx_rates` | Currency reference data | `rate`, `source`, `audit` |

### Row-key strategy

- `trade_transactions`: `TF-<year>-<sequence>`. A known transaction ID is an
  exact row key, so HBase can retrieve it without scanning the full table.
- `trade_events`: `<transaction_id>#<event_time>#<event_id>`. Events for one
  transaction share a prefix and sort chronologically, supporting a focused
  lifecycle scan.
- `trade_documents`: the document ID is the key, with the transaction ID stored
  in `document:transaction_id`.
- `trade_ml_results`: the result key identifies one prediction or forecast.
- `trade_fx_rates`: `<base><quote>`, such as `USDCAD`, provides direct rate
  lookup.

The sequential transaction suffix is clear and suitable for this single-node
classroom system. A large production cluster could add a short hash prefix to
spread new writes across regions and reduce hot-spotting.

### PUT, GET, and SCAN demonstration

Run:

```bash
bash scripts/trade-finance/hbase-operations.sh
```

The script idempotently writes the demo row `TF-DEMO-MEMBER2-0001`, retrieves
it with `get`, scans a small transaction prefix, and scans the event-history
prefix. To look up a generated transaction instead, pass its ID:

```bash
bash scripts/trade-finance/hbase-operations.sh TF-2026-0000001
```

The demo row is intentionally retained so it can be queried from both HBase and
the Hive external table.
