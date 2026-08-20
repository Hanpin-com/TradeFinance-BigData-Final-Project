# Trade Finance Intelligence & Risk Management MIS - Final Implementation

This package is designed to be copied into the existing `BigDataEnvironment`.

## Important architecture decisions
- One `docker-compose.yml` only.
- Existing Kafka is reused and remains Kafka 4.0 KRaft.
- Existing ZooKeeper is used by HBase only.
- Existing HBase and its Thrift server on 9090 are reused.
- Existing HiveServer2 on 10000 is reused.
- Existing Spark/Hadoop/HDFS/Zeppelin/SQL Server services are not duplicated.
- Power BI Desktop runs on Windows outside Docker.

## New runtime containers
- `tf-data-generator`
- `tf-event-producer`
- `tf-hbase-consumer`
- `tf-ml-worker`

## Implemented source simulation
The generator produces realistic synthetic, connected Trade Finance lifecycle events for:
- Letters of Credit
- Guarantees
- Documentary Collections
- Documents and discrepancies
- Shipments
- Payments
- Compliance screening
- Sanctions screening
- Credit/limit checks
- FX reference rates

## Kafka
`tf-event-producer` uses Kafka AdminClient to create missing `tf.*` topics automatically.
No Kafka initialization container is required.

## HBase
`tf-hbase-consumer` creates missing Trade Finance HBase tables through the existing HBase Thrift endpoint.
No HBase initialization container is required.

## Hive
`tf-hbase-consumer` attempts to apply `sql/TradeFinance/01-hive-schema.sql` through the existing HiveServer2.
If the existing Hive image does not expose the HBaseStorageHandler dependencies correctly, the same SQL file can be executed manually inside `hive-server` for diagnosis.

## ML models implemented
1. Transaction anomaly detection - Isolation Forest
2. Documentary discrepancy prediction - Random Forest classification
3. Processing delay prediction - Random Forest classification + regression
4. Monthly trade volume forecast - Holt-Winters/Exponential Smoothing

Model outputs are written to `trade_ml_results` in HBase and published to `tf.ml.*` Kafka topics.

## Before build
Copy the contents of this package over your repository root, preserving your existing Dockerfiles/scripts.

Validate:
`docker compose config`

Then build only the new image first:
`docker compose build tf-data-generator tf-event-producer tf-hbase-consumer tf-ml-worker`

Then start the base platform:
`docker compose up -d namenode datanode resourcemanager nodemanager zookeeper kafka hive-metastore-postgresql hive-metastore hive-server hbase`

After those are healthy:
`docker compose up -d tf-data-generator`
`docker compose up -d tf-event-producer tf-hbase-consumer tf-ml-worker`

Validate:
`bash scripts/trade-finance/validate-trade-finance.sh`

## Member branches
- `member1-business-architecture` — Business case, dataset, architecture, HDFS, YARN (see `member1/`)
- `member2-hive-hbase` — Historical Hive / HBase
- `member3-streaming` — Kafka / Spark streaming
- `member4-vedant` — ML / Power BI
